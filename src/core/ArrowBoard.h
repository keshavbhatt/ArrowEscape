#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QPoint>
#include <QVector>
#include <QtQmlIntegration/qqmlintegration.h>

// ArrowBoard — the game logic for the tangled "arrow snakes" puzzle, exposed to
// QML as a list model (one row per snake) plus board-level properties.
//
// Each arrow is a winding *snake*: a connected path of grid cells ending in a
// head that points in one cardinal direction. Tapping a snake launches it off
// the board in its head's direction — but only if the straight lane from the
// head to the edge is clear of other snakes' cells. A snake's body is what tangles
// across other snakes' lanes; removing it frees every cell it occupied.
//
// Levels are generated *solvable by construction*: each snake is placed so that,
// against the snakes already on the board, its head lane to the edge is clear.
// Removing snakes in reverse placement order is therefore always a full solution,
// and since launching only frees cells, no reachable state is ever stranded.
class ArrowBoard : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int rows       READ rows       NOTIFY boardChanged)
    Q_PROPERTY(int cols       READ cols       NOTIFY boardChanged)
    Q_PROPERTY(int level      READ level      NOTIFY levelChanged)
    Q_PROPERTY(int drops      READ drops      NOTIFY dropsChanged)
    Q_PROPERTY(int maxDrops   READ maxDrops   NOTIFY dropsChanged)
    Q_PROPERTY(int remaining  READ remaining  NOTIFY remainingChanged)
    Q_PROPERTY(qreal progress READ progress   NOTIFY remainingChanged)
    Q_PROPERTY(Status status  READ status     NOTIFY statusChanged)
    Q_PROPERTY(bool pictureMode READ pictureMode NOTIFY boardChanged)

public:
    enum Direction { Up = 0, Right = 1, Down = 2, Left = 3 };
    Q_ENUM(Direction)

    enum Status { Playing, Won, Lost };
    Q_ENUM(Status)

    enum Roles {
        IdRole = Qt::UserRole + 1,
        DirRole,
        EscapingRole,
        CellsRole,      // QVariantList of QPointF(col, row) — the snake's path
    };

    explicit ArrowBoard(QObject *parent = nullptr);

    // ── QAbstractListModel ──
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // ── Board properties ──
    int rows() const { return m_rows; }
    int cols() const { return m_cols; }
    int level() const { return m_level; }
    int drops() const { return m_drops; }
    int maxDrops() const { return m_maxDrops; }
    int remaining() const;             // snakes not yet launching
    qreal progress() const;            // fraction of the level cleared, 0..1
    Status status() const { return m_status; }
    bool pictureMode() const { return m_pictureMode; }

    // ── Actions driven from QML ──
    Q_INVOKABLE void startLevel(int level);
    Q_INVOKABLE void nextLevel();
    // Generate a fully-packed, solvable board in the shape of `maskRows` (one
    // string per row; '#'/'1' = a filled cell). Seeded by `seed` for determinism.
    Q_INVOKABLE void startPicture(int cols, int rows, const QString &maskRows, int seed);
    Q_INVOKABLE void restart();
    Q_INVOKABLE void addLives();             // "Free Lives": refill drops, resume the board
    Q_INVOKABLE void tap(int id);            // launch a snake (or bounce if blocked)
    Q_INVOKABLE void finishEscape(int id);   // QML calls this when the fly-off ends
    Q_INVOKABLE int  hint() const;           // id of a snake that can launch now, or -1

signals:
    void boardChanged();
    void levelChanged();
    void dropsChanged();
    void remainingChanged();
    void statusChanged();
    void blocked(int id);   // a tap could not launch: QML flashes the snake
    void escaped(int id);   // a tap succeeded: the snake is flying off
    void won();
    void lost();

private:
    struct Arrow {
        int            id;
        QVector<QPoint> cells;   // path, tail → head; head = cells.last(); QPoint(col,row)
        int            dir;      // head direction
        bool           escaping = false;
    };

    int  indexOfId(int id) const;
    int  key(int col, int row) const { return row * m_cols + col; }
    bool laneClear(int arrowIndex) const;     // head lane to the edge is empty
    void rebuildOwner();
    // Fully-packed, solvable-by-construction via reverse peeling. lenMin/lenMax
    // set snake length; longBiasPct is the % chance of peeling one of the longest
    // available lanes (higher ⇒ arrows point deeper inward ⇒ more tangled/harder).
    void generate(int rows, int cols, int lenMin, int lenMax, int longBiasPct);
    void setStatus(Status s);

    QVector<Arrow>    m_arrows;
    QVector<Arrow>    m_initial;   // pristine snapshot for restart()
    QHash<int, int>   m_owner;     // cell key → index into m_arrows (non-escaping only)
    QVector<char>     m_mask;      // per-cell fill mask (empty ⇒ full rectangle)
    bool              m_pictureMode = false;
    int    m_rows = 0;
    int    m_cols = 0;
    int    m_level = 0;
    int    m_drops = 0;
    int    m_maxDrops = 3;
    int    m_initialCount = 0;   // snakes at level start, for progress()
    int    m_nextId = 1;
    Status m_status = Playing;
};
