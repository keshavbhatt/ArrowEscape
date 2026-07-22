#include "AppInfo.h"
#include "ArrowBoard.h"
#ifdef AE_DEBUG
#include "LicenseController.h"
#endif

#include <QGuiApplication>
#include <QIcon>
#include <QMouseEvent>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
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

    // Dev-only: AE_BLOCKTAP=<dir> taps an arrow whose lane is NOT clear, capturing
    // the blocked-tap red flash + shake and the heart-loss animation together in a
    // burst of frames. Inert unless set. Debug builds only — it relies on
    // ArrowBoard::debugBlockedId(), which is compiled out of release.
#ifdef AE_DEBUG
    const QByteArray blockDir = qgetenv("AE_BLOCKTAP");
    if (!blockDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [blockDir, startLevel, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                auto *board = w->findChild<ArrowBoard *>();
                if (!board) { app.quit(); return; }
                w->setProperty("screen", 1);
                if (startLevel > 0) board->startLevel(startLevel);
                int *frame = new int(0);
                auto grab = [w, blockDir, frame]() {
                    w->grabWindow().save(QString::fromUtf8(blockDir)
                        + QString("/b%1.png").arg(*frame, 3, 10, QChar('0')));
                    ++(*frame);
                };
                QTimer::singleShot(700, &app, [board, grab, &app]() {
                    grab();                                   // before
                    // Tap a genuinely blocked arrow so it bounces (red flash + one
                    // heart lost) instead of launching.
                    const int target = board->debugBlockedId();
                    if (target > 0) board->tap(target);
                    for (int t = 1; t <= 20; ++t)
                        QTimer::singleShot(t * 33, &app, grab);   // during the flash
                    QTimer::singleShot(900, &app, [&app] { app.quit(); });
                });
            }, Qt::QueuedConnection);
    }
#endif // AE_DEBUG

    // Dev-only: AE_REFILL=<dir> drains all hearts (blocked taps → Lost), then calls
    // addLives() and captures the header hearts to confirm they re-render as filled.
#ifdef AE_DEBUG
    const QByteArray refillDir = qgetenv("AE_REFILL");
    if (!refillDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [refillDir, startLevel, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                auto *board = w->findChild<ArrowBoard *>();
                if (!board) { app.quit(); return; }
                w->setProperty("screen", 1);
                if (startLevel > 0) board->startLevel(startLevel);
                int *frame = new int(0);
                auto grab = [w, refillDir, frame]() {
                    w->grabWindow().save(QString::fromUtf8(refillDir)
                        + QString("/f%1.png").arg(*frame, 3, 10, QChar('0')));
                    ++(*frame);
                };
                QTimer::singleShot(700, &app, [board, grab, &app]() {
                    // Drain every heart by tapping blocked arrows.
                    for (int k = 0; k < 8 && board->drops() > 0; ++k) {
                        const int b = board->debugBlockedId();
                        if (b > 0) board->tap(b);
                    }
                    grab();                                   // hearts empty
                    board->addLives();                        // refill
                    grab();                                   // should be filled again
                    for (int t = 1; t <= 8; ++t)
                        QTimer::singleShot(t * 60, &app, grab);
                    QTimer::singleShot(700, &app, [&app] { app.quit(); });
                });
            }, Qt::QueuedConnection);
    }

    // Dev-only trial-clock checks (all synchronous, no network):
    //   AE_LICREAD    print days-remaining from the *persisted* start (no write)
    //   AE_LICSET=<n> backdate the persisted start by n days, then print
    //   AE_LICTEST    print the countdown for elapsed 0..6 days
    if (!qEnvironmentVariableIsEmpty("AE_LICREAD")
        || !qEnvironmentVariableIsEmpty("AE_LICSET")
        || !qEnvironmentVariableIsEmpty("AE_LICTEST")) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [&engine, &app](QObject *, const QUrl &) {
                auto *lc = engine.singletonInstance<LicenseController *>(
                    "ArrowEscape", "LicenseController");
                if (lc) {
                    if (!qEnvironmentVariableIsEmpty("AE_LICREAD"))
                        printf("LICREAD persisted daysLeft=%d\n", lc->debugReadTrialDays());
                    if (!qEnvironmentVariableIsEmpty("AE_LICSET")) {
                        const int n = qEnvironmentVariableIntValue("AE_LICSET");
                        lc->debugTrialDaysAfter(n);
                        printf("LICSET backdated %dd -> persisted daysLeft=%d\n",
                               n, lc->debugReadTrialDays());
                    }
                    if (!qEnvironmentVariableIsEmpty("AE_LICTEST"))
                        for (int d = 0; d <= 6; ++d)
                            printf("LICTEST elapsed=%dd -> daysLeft=%d\n",
                                   d, lc->debugTrialDaysAfter(d));
                    fflush(stdout);
                }
                app.quit();
            }, Qt::QueuedConnection);
    }

    // Dev-only: AE_HINTSPAM rapidly "clicks" the hint button several times and
    // prints hintsLeft before/after — proving repeated taps spend at most one hint.
    if (!qEnvironmentVariableIsEmpty("AE_HINTSPAM")) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [startLevel, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                auto *board = w->findChild<ArrowBoard *>();
                if (!board) { app.quit(); return; }
                w->setProperty("screen", 1);
                board->startLevel(startLevel > 0 ? startLevel : 5);
                QTimer::singleShot(700, &app, [w, &app]() {
                    auto *tool = w->findChild<QObject *>(QStringLiteral("hintTool"));
                    const int before = w->property("hintsLeft").toInt();
                    for (int i = 0; i < 6; ++i)                 // 6 rapid taps
                        if (tool) QMetaObject::invokeMethod(tool, "clicked");
                    const int after = w->property("hintsLeft").toInt();
                    printf("HINTSPAM before=%d after=%d (6 rapid clicks)\n", before, after);
                    fflush(stdout);
                    app.quit();
                });
            }, Qt::QueuedConnection);
    }

    // Dev-only: AE_NAV=<dir> navigates Home → Levels and grabs a burst of frames
    // to capture the page-slide transition. Inert unless set.
    const QByteArray navDir = qgetenv("AE_NAV");
    if (!navDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [navDir, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                w->setProperty("screen", 0);              // start on Home
                int *frame = new int(0);
                auto grab = [w, navDir, frame]() {
                    w->grabWindow().save(QString::fromUtf8(navDir)
                        + QString("/s%1.png").arg(*frame, 3, 10, QChar('0')));
                    ++(*frame);
                };
                QTimer::singleShot(600, &app, [w, grab, &app]() {
                    grab();                                // Home, before
                    w->setProperty("screen", 2);           // slide to Levels
                    for (int t = 1; t <= 14; ++t)
                        QTimer::singleShot(t * 28, &app, grab);
                    QTimer::singleShot(600, &app, [&app] { app.quit(); });
                });
            }, Qt::QueuedConnection);
    }
    // Dev-only: AE_INPUTTEST synthesizes real mouse wheel / drag / click events
    // through the window's event delivery and prints whether the board content
    // zoomed, panned, and still receives taps — headless verification of the
    // pan/zoom input chain. Inert unless set.
    if (!qEnvironmentVariableIsEmpty("AE_INPUTTEST")) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [startLevel, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                w->setProperty("screen", 1);
                auto *board = w->findChild<ArrowBoard *>();
                if (board) board->startLevel(startLevel > 0 ? startLevel : 60);
                QTimer::singleShot(1400, &app, [w, board, &app]() {
                    auto *view    = w->findChild<QQuickItem *>(QStringLiteral("boardView"));
                    auto *content = w->findChild<QQuickItem *>(QStringLiteral("boardContent"));
                    if (!view || !content || !board) {
                        printf("INPUTTEST FAIL missing boardView/boardContent/board\n");
                        fflush(stdout); app.quit(); return;
                    }
                    ulong ts = 100000;
                    const QPointF c = view->mapToScene(
                        QPointF(view->width() / 2, view->height() / 2));

                    // 1) Wheel-zoom in 5 notches at the board centre.
                    const qreal s0 = content->scale();
                    for (int i = 0; i < 5; ++i) {
                        QWheelEvent wh(c, w->mapToGlobal(c.toPoint()), QPoint(),
                                       QPoint(0, 120), Qt::NoButton, Qt::NoModifier,
                                       Qt::NoScrollPhase, false);
                        wh.setTimestamp(ts += 50);
                        QCoreApplication::sendEvent(w, &wh);
                    }
                    QCoreApplication::processEvents();
                    const qreal s1 = content->scale();
                    printf("INPUTTEST wheel  scale %.3f -> %.3f  %s\n",
                           s0, s1, s1 > s0 + 0.01 ? "OK" : "FAIL");

                    // 1b) Wayland-style phased scroll: zero-delta begin/end
                    // markers around hi-res updates must still zoom IN overall.
                    const qreal sp0 = content->scale();
                    const struct { int dy; Qt::ScrollPhase ph; } seq[] = {
                        { 0, Qt::ScrollBegin }, { 40, Qt::ScrollUpdate },
                        { 40, Qt::ScrollUpdate }, { 40, Qt::ScrollUpdate },
                        { 0, Qt::ScrollEnd },
                    };
                    for (const auto &st : seq) {
                        QWheelEvent wh(c, w->mapToGlobal(c.toPoint()), QPoint(),
                                       QPoint(0, st.dy), Qt::NoButton, Qt::NoModifier,
                                       st.ph, false);
                        wh.setTimestamp(ts += 20);
                        QCoreApplication::sendEvent(w, &wh);
                    }
                    QCoreApplication::processEvents();
                    const qreal sp1 = content->scale();
                    printf("INPUTTEST phased scale %.3f -> %.3f  %s\n",
                           sp0, sp1, sp1 > sp0 + 0.01 ? "OK" : "FAIL");

                    // 2) Drag from the centre (content now overflows the view).
                    const qreal x0 = content->x(), y0 = content->y();
                    QPointF p = c;
                    QMouseEvent press(QEvent::MouseButtonPress, p, p,
                                      w->mapToGlobal(p.toPoint()),
                                      Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
                    press.setTimestamp(ts += 60);
                    QCoreApplication::sendEvent(w, &press);
                    for (int i = 1; i <= 8; ++i) {
                        p = c + QPointF(-11 * i, -8 * i);
                        QMouseEvent move(QEvent::MouseMove, p, p,
                                         w->mapToGlobal(p.toPoint()),
                                         Qt::NoButton, Qt::LeftButton, Qt::NoModifier);
                        move.setTimestamp(ts += 25);
                        QCoreApplication::sendEvent(w, &move);
                        QCoreApplication::processEvents();
                    }
                    QMouseEvent rel(QEvent::MouseButtonRelease, p, p,
                                    w->mapToGlobal(p.toPoint()),
                                    Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
                    rel.setTimestamp(ts += 25);
                    QCoreApplication::sendEvent(w, &rel);
                    QCoreApplication::processEvents();
                    const bool panned = qAbs(content->x() - x0) + qAbs(content->y() - y0) > 1.0;
                    printf("INPUTTEST drag   pos (%.0f,%.0f) -> (%.0f,%.0f)  %s\n",
                           x0, y0, content->x(), content->y(), panned ? "OK" : "FAIL");

                    // 3) A clean click on a snake must still tap it.
                    bool tapReached = false;
                    QObject::connect(board, &ArrowBoard::escaped, &app,
                                     [&tapReached](int) { tapReached = true; });
                    QObject::connect(board, &ArrowBoard::blocked, &app,
                                     [&tapReached](int) { tapReached = true; });
                    const QPointF click = view->mapToScene(
                        QPointF(view->width() / 2, view->height() / 2));
                    QMouseEvent cp(QEvent::MouseButtonPress, click, click,
                                   w->mapToGlobal(click.toPoint()),
                                   Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
                    cp.setTimestamp(ts += 200);
                    QCoreApplication::sendEvent(w, &cp);
                    QMouseEvent cr(QEvent::MouseButtonRelease, click, click,
                                   w->mapToGlobal(click.toPoint()),
                                   Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
                    cr.setTimestamp(ts += 40);
                    QCoreApplication::sendEvent(w, &cr);
                    QCoreApplication::processEvents();
                    printf("INPUTTEST click  tap %s\n", tapReached ? "OK" : "FAIL");
                    fflush(stdout);

                    // 3b) Hover: a buttonless move must highlight the snake
                    // under the cursor (visual check via the saved PNG).
                    const QPointF hp = click + QPointF(34, 34);
                    QMouseEvent hov(QEvent::MouseMove, hp, hp,
                                    w->mapToGlobal(hp.toPoint()),
                                    Qt::NoButton, Qt::NoButton, Qt::NoModifier);
                    hov.setTimestamp(ts += 80);
                    QCoreApplication::sendEvent(w, &hov);
                    QCoreApplication::processEvents();
                    if (qgetenv("AE_INPUTTEST").size() > 1)
                        w->grabWindow().save(QString::fromUtf8(qgetenv("AE_INPUTTEST"))
                                             + "/hover.png");

                    // 4) Orientation reset: tilt the board as a rotating pinch
                    // would, then straighten it via the reset button's path.
                    // AE_INPUTTEST=<dir> additionally saves before/after PNGs.
                    const QByteArray dir = qgetenv("AE_INPUTTEST");
                    content->setProperty("rotation", 33.0);
                    QCoreApplication::processEvents();
                    if (dir.size() > 1)
                        w->grabWindow().save(QString::fromUtf8(dir) + "/rot-before.png");
                    QMetaObject::invokeMethod(view, "resetOrientation");
                    QTimer::singleShot(500, &app, [w, content, dir, &app]() {
                        const qreal r = content->rotation();
                        printf("INPUTTEST rotate 33.0 -> %.1f  %s\n",
                               r, qAbs(r) < 0.01 ? "OK" : "FAIL");
                        fflush(stdout);
                        if (dir.size() > 1)
                            w->grabWindow().save(QString::fromUtf8(dir) + "/rot-after.png");
                        app.quit();
                    });
                });
            }, Qt::QueuedConnection);
    }
#endif // AE_DEBUG

    // Dev-only: AE_HINT=<dir> triggers a hint and grabs a burst of frames to
    // capture the hinted arrow's bob animation. Inert unless set.
    const QByteArray hintDir = qgetenv("AE_HINT");
    if (!hintDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [hintDir, startLevel, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                w->setProperty("screen", 1);
                if (auto *b = w->findChild<ArrowBoard *>(); b && startLevel > 0)
                    b->startLevel(startLevel);
                auto *view = w->findChild<QObject *>(QStringLiteral("boardView"));
                if (!view) { app.quit(); return; }
                int *frame = new int(0);
                auto grab = [w, hintDir, frame]() {
                    w->grabWindow().save(QString::fromUtf8(hintDir)
                        + QString("/n%1.png").arg(*frame, 3, 10, QChar('0')));
                    ++(*frame);
                };
                QTimer::singleShot(700, &app, [view, grab, &app]() {
                    grab();                                   // before
                    QMetaObject::invokeMethod(view, "showHint");
                    for (int t = 1; t <= 24; ++t)
                        QTimer::singleShot(t * 40, &app, grab);   // during the bob
                    QTimer::singleShot(1100, &app, [&app] { app.quit(); });
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
