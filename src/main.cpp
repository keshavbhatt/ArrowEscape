#include "AppInfo.h"
#include "ArrowBoard.h"

#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Identity — set before any QSettings-derived storage is touched.
    QGuiApplication::setOrganizationName(QStringLiteral(AE_ORG_NAME));
    QGuiApplication::setApplicationName(QStringLiteral(AE_APP_NAME));
    QGuiApplication::setApplicationVersion(QStringLiteral(AE_VERSION));
    QGuiApplication::setDesktopFileName(QStringLiteral(AE_APP_ID));
    QGuiApplication::setWindowIcon(
        QIcon(QStringLiteral(":/assets/icons/" AE_APP_ID ".svg")));

    // Basic (non-native) Quick Controls style: full control over theming so the
    // board looks identical across platforms.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QQmlApplicationEngine engine;

    // Expose whether this is a debug build to QML, which unlocks the in-app level
    // jumper / unlock-all testing aids. Always set so `appDebug` is defined.
#ifdef AE_DEBUG
    engine.rootContext()->setContextProperty("appDebug", true);
#else
    engine.rootContext()->setContextProperty("appDebug", false);
#endif
    // Dev-only: AE_PIC=<pictureId> auto-plays that Picture Pack board on launch.
    engine.rootContext()->setContextProperty("aePic", QString::fromUtf8(qgetenv("AE_PIC")));
    // Dev-only: AE_TIER=free|trial|pro forces a licence tier (debug builds).
    engine.rootContext()->setContextProperty("aeTier", QString::fromUtf8(qgetenv("AE_TIER")));

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    // Dev-only: AE_SHOT=<path> renders once, saves a PNG, and quits — used for
    // headless visual verification. Inert unless the env var is set.
    const QByteArray shot = qgetenv("AE_SHOT");
    const int startLevel = qEnvironmentVariableIntValue("AE_LEVEL");
    if (!shot.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [shot, startLevel, &app](QObject *obj, const QUrl &) {
                if (auto *w = qobject_cast<QQuickWindow *>(obj)) {
                    if (startLevel > 0) {
                        w->setProperty("screen", 1);   // show the game screen
                        if (auto *b = w->findChild<ArrowBoard *>())
                            b->startLevel(startLevel);
                    }
                    if (!qEnvironmentVariableIsEmpty("AE_OPENSETTINGS"))
                        w->setProperty("settingsOpen", true);
                    if (!qEnvironmentVariableIsEmpty("AE_OPENABOUT"))
                        w->setProperty("aboutOpen", true);
                    if (!qEnvironmentVariableIsEmpty("AE_ALBUM"))
                        w->setProperty("screen", 2);
                    if (!qEnvironmentVariableIsEmpty("AE_UPGRADE"))
                        w->setProperty("upgradeOpen", true);
                    QTimer::singleShot(900, [w, shot, &app] {
                        w->grabWindow().save(QString::fromUtf8(shot));
                        app.quit();
                    });
                }
            }, Qt::QueuedConnection);
    }

    // Dev-only: AE_AUTOPLAY=<dir> auto-solves the opening board through the real
    // tap() path (tapping the hinted escapable arrow each step) and saves a
    // numbered filmstrip of PNG frames — headless gameplay verification. Inert
    // unless the env var is set.
    const QByteArray autoDir = qgetenv("AE_AUTOPLAY");
    if (!autoDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [autoDir, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                auto *board = w->findChild<ArrowBoard *>();
                if (!board) { app.quit(); return; }
                w->setProperty("screen", 1);

                int *frame = new int(0);
                auto grab = [w, autoDir, frame]() {
                    const QString p = QString::fromUtf8(autoDir)
                        + QString("/f%1.png").arg(*frame, 3, 10, QChar('0'));
                    w->grabWindow().save(p);
                    ++(*frame);
                };

                auto *t = new QTimer(&app);
                t->setInterval(650);
                QObject::connect(t, &QTimer::timeout, &app, [board, t, grab, &app]() {
                    const int id = board->hint();
                    if (id > 0) {
                        board->tap(id);
                        QTimer::singleShot(150, &app, grab);   // catch it mid-flight
                    } else {
                        t->stop();
                        QTimer::singleShot(300, &app, grab);   // the "Cleared!" overlay
                        QTimer::singleShot(750, &app, [&app] { app.quit(); });
                    }
                });
                QTimer::singleShot(500, &app, grab);           // the opening board
                t->start();
            }, Qt::QueuedConnection);
    }

    // Dev-only: AE_STREAK=<dir> taps one hinted arrow and grabs a burst of frames
    // (~33ms apart) to capture the launch animation. Inert unless set.
    const QByteArray streakDir = qgetenv("AE_STREAK");
    if (!streakDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [streakDir, startLevel, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                auto *board = w->findChild<ArrowBoard *>();
                if (!board) { app.quit(); return; }
                w->setProperty("screen", 1);
                if (startLevel > 0) board->startLevel(startLevel);
                int *frame = new int(0);
                auto grab = [w, streakDir, frame]() {
                    w->grabWindow().save(QString::fromUtf8(streakDir)
                        + QString("/k%1.png").arg(*frame, 3, 10, QChar('0')));
                    ++(*frame);
                };
                QTimer::singleShot(700, &app, [board, grab, &app]() {
                    grab();                                   // before
                    const int id = board->hint();
                    if (id > 0) board->tap(id);
                    for (int t = 1; t <= 16; ++t)
                        QTimer::singleShot(t * 33, &app, grab);   // during the launch
                    QTimer::singleShot(900, &app, [&app] { app.quit(); });
                });
            }, Qt::QueuedConnection);
    }

    // Dev-only: AE_INTRO=<dir> grabs a burst of frames right at load to capture
    // the board entrance animation. Inert unless set.
    const QByteArray introDir = qgetenv("AE_INTRO");
    if (!introDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [introDir, startLevel, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                w->setProperty("screen", 1);
                if (startLevel > 0)
                    if (auto *b = w->findChild<ArrowBoard *>()) b->startLevel(startLevel);
                int *frame = new int(0);
                auto grab = [w, introDir, frame]() {
                    w->grabWindow().save(QString::fromUtf8(introDir)
                        + QString("/i%1.png").arg(*frame, 3, 10, QChar('0')));
                    ++(*frame);
                };
                for (int t = 0; t <= 18; ++t)
                    QTimer::singleShot(t * 55, &app, grab);
                QTimer::singleShot(1150, &app, [&app] { app.quit(); });
            }, Qt::QueuedConnection);
    }

    // Dev-only: AE_SHAPE=heart|star|moon generates a picture board and (with
    // AE_SHOT set) screenshots it after the draw-in. Prototype for Picture Packs.
    const QByteArray shape = qgetenv("AE_SHAPE");
    if (!shape.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [shape, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                auto *b = w->findChild<ArrowBoard *>();
                if (!b) { app.quit(); return; }
                w->setProperty("screen", 1);
                const QString name = QString::fromUtf8(shape);
                int cols = 15, rows = 15;
                QString mask;
                if (name == "heart") {
                    cols = 13; rows = 12;
                    mask = "..##.....##..\n.#####.#####.\n#############\n#############\n"
                           "#############\n#############\n#############\n#############\n"
                           ".###########.\n..#########..\n..#########..\n....#####....";
                } else if (name == "moon") {
                    cols = 14; rows = 14;
                    mask = ".....####.....\n...######.....\n..#####.......\n.#####........\n"
                           ".####.........\n#####.........\n#####.........\n#####.........\n"
                           "#####.........\n.####.........\n.#####........\n..#####.......\n"
                           "...######.....\n.....####.....";
                } else {
                    mask = ".......#.......\n......###......\n......###......\n......###......\n"
                           "...#..###..#...\n.#############.\n.#############.\n..###########..\n"
                           ".....#####.....\n....#######....\n...#########...\n...####.####...\n"
                           "...###...###...\n...............\n...............";
                }
                b->startPicture(cols, rows, mask, 7);
                const QByteArray shot = qgetenv("AE_SHOT");
                if (!shot.isEmpty())
                    QTimer::singleShot(1600, &app, [w, shot, &app] {
                        w->grabWindow().save(QString::fromUtf8(shot));
                        app.quit();
                    });
            }, Qt::QueuedConnection);
    }

    engine.loadFromModule("ArrowEscape", "Main");

    return app.exec();
}
