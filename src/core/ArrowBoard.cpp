#include "ArrowBoard.h"

#include <QRandomGenerator>
#include <QSet>
#include <algorithm>

namespace {
// Unit step for each direction, as (dCol, dRow).
constexpr int kDC[4] = {  0,  1,  0, -1 };  // Up, Right, Down, Left
constexpr int kDR[4] = { -1,  0,  1,  0 };
}

ArrowBoard::ArrowBoard(QObject *parent)
    : QAbstractListModel(parent)
{
    startLevel(1);
}

// ── Model ────────────────────────────────────────────────────────────────────

int ArrowBoard::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_arrows.size();
}

QVariant ArrowBoard::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_arrows.size())
        return {};
    const Arrow &a = m_arrows.at(index.row());
    switch (role) {
    case IdRole:       return a.id;
    case DirRole:      return a.dir;
    case EscapingRole: return a.escaping;
    case CellsRole: {
        QVariantList pts;
        pts.reserve(a.cells.size());
        for (const QPoint &p : a.cells)
            pts.push_back(QPointF(p.x(), p.y()));   // x = col, y = row
        return pts;
    }
    default: return {};
    }
}

QHash<int, QByteArray> ArrowBoard::roleNames() const
{
    return {
        { IdRole,       "arrowId" },
        { DirRole,      "dir" },
        { EscapingRole, "escaping" },
        { CellsRole,    "cells" },
    };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

int ArrowBoard::indexOfId(int id) const
{
    for (int i = 0; i < m_arrows.size(); ++i)
        if (m_arrows.at(i).id == id)
            return i;
    return -1;
}

int ArrowBoard::remaining() const
{
    int n = 0;
    for (const Arrow &a : m_arrows)
        if (!a.escaping)
            ++n;
    return n;
}

qreal ArrowBoard::progress() const
{
    if (m_initialCount <= 0)
        return 0.0;
    return qreal(m_initialCount - remaining()) / qreal(m_initialCount);
}

void ArrowBoard::rebuildOwner()
{
    m_owner.clear();
    for (int i = 0; i < m_arrows.size(); ++i) {
        const Arrow &a = m_arrows.at(i);
        if (a.escaping)
            continue;
        for (const QPoint &p : a.cells)
            m_owner.insert(key(p.x(), p.y()), i);
    }
}

// True if every cell from the arrow's head toward the edge (in its head
// direction) is free of other, non-escaping snakes.
bool ArrowBoard::laneClear(int arrowIndex) const
{
    const Arrow &a = m_arrows.at(arrowIndex);
    const QPoint head = a.cells.last();
    int c = head.x() + kDC[a.dir];
    int r = head.y() + kDR[a.dir];
    while (c >= 0 && c < m_cols && r >= 0 && r < m_rows) {
        const auto it = m_owner.constFind(key(c, r));
        if (it != m_owner.constEnd() && it.value() != arrowIndex)
            return false;
        c += kDC[a.dir];
        r += kDR[a.dir];
    }
    return true;
}

// ── Generation (dense, solvable by construction) ─────────────────────────────
//
// Two stages, both preserving the invariant that every snake's head lane to the
// edge is clear of *earlier-placed* snakes (so reverse placement order solves):
//   1. Multi-pass placement — grow winding snakes (long first, then shorter,
//      finally single cells) whose head lane is clear of what's already down.
//   2. Guarded tail-repair — grow existing snakes' *tails* into leftover empty
//      cells, never into any snake's head-lane ray. Heads and their lanes are
//      untouched, so solvability is preserved while density climbs to ~90%.

void ArrowBoard::generate(int rows, int cols)
{
    beginResetModel();
    m_arrows.clear();
    m_owner.clear();
    m_rows = rows;
    m_cols = cols;
    m_nextId = 1;

    QVector<int> occ(rows * cols, -1);   // cell key → placed snake index, or -1
    auto isFree = [&](int c, int r) {
        return c >= 0 && c < cols && r >= 0 && r < rows && occ[r * cols + c] < 0;
    };

    QRandomGenerator *rng = QRandomGenerator::global();

    // Head lane clear of placed snakes (and of the snake being placed, `path`).
    auto headLaneClear = [&](QPoint head, int dir, const QVector<QPoint> &path) {
        int c = head.x() + kDC[dir], r = head.y() + kDR[dir];
        while (c >= 0 && c < cols && r >= 0 && r < rows) {
            if (!isFree(c, r) || path.contains(QPoint(c, r)))
                return false;
            c += kDC[dir];
            r += kDR[dir];
        }
        return true;
    };

    // Distance from a cell to the board edge in direction d (for outward bias).
    auto edgeDist = [&](QPoint p, int d) {
        switch (d) {
        case 0:  return p.y();
        case 1:  return cols - 1 - p.x();
        case 2:  return rows - 1 - p.y();
        default: return p.x();
        }
    };

    // ── Stage 1: multi-pass placement ──
    // Snakes are at least 2 cells (a shaft + a head) — no lone single-cell
    // arrows, which read as strange stray triangles. Leftover gaps are filled by
    // the tail-repair stage below instead.
    struct Pass { int lenMin, lenMax, budget; };
    const int cells = rows * cols;
    const QVector<Pass> passes = {
        { 5, 9, cells * 3 }, { 3, 6, cells * 3 }, { 2, 3, cells * 5 },
    };

    for (const Pass &pass : passes) {
        for (int att = 0; att < pass.budget; ++att) {
            const int sc = rng->bounded(cols), sr = rng->bounded(rows);
            if (!isFree(sc, sr))
                continue;
            const QPoint head(sc, sr);

            // Pick the head direction so that (a) its lane to the edge is clear and
            // (b) the cell *behind* the head is free — so the body can approach the
            // head in a straight line and the arrowhead continues the line (the way
            // the reference game draws it). Fall back to a single-cell arrow only in
            // the length-1 pass.
            QVector<int> dirs;
            for (int d = 0; d < 4; ++d) {
                const QPoint back(head.x() - kDC[d], head.y() - kDR[d]);
                if (headLaneClear(head, d, { head }) && isFree(back.x(), back.y()))
                    dirs.push_back(d);
            }

            if (dirs.isEmpty())
                continue;

            // Outward bias (nearest edge) with some variety.
            std::sort(dirs.begin(), dirs.end(),
                      [&](int a, int b) { return edgeDist(head, a) < edgeDist(head, b); });
            const int headDir = (rng->bounded(100) < 60) ? dirs.first()
                                                         : dirs.at(rng->bounded(dirs.size()));

            // Body grows backward from the head. The FIRST step is forced opposite
            // to headDir (a straight approach). Subsequent steps strongly prefer to
            // keep going straight, so snakes read as long grid runs with occasional
            // 90° turns rather than a wiggle.
            const int target = pass.lenMin + rng->bounded(pass.lenMax - pass.lenMin + 1);
            QVector<QPoint> path{ head };
            int growDir = (headDir + 2) % 4;                      // opposite of headDir
            QPoint cur(head.x() + kDC[growDir], head.y() + kDR[growDir]);
            path.prepend(cur);

            for (int guard = 0; path.size() < target && guard < 60; ++guard) {
                // Straight continuation preferred.
                const QPoint straight(cur.x() + kDC[growDir], cur.y() + kDR[growDir]);
                QVector<int> turnDirs;
                for (int d = 0; d < 4; ++d) {
                    if (d == (growDir + 2) % 4)   // never reverse into the body
                        continue;
                    const QPoint n(cur.x() + kDC[d], cur.y() + kDR[d]);
                    if (isFree(n.x(), n.y()) && !path.contains(n))
                        turnDirs.push_back(d);
                }
                if (turnDirs.isEmpty())
                    break;
                const bool canStraight = turnDirs.contains(growDir);
                int d;
                if (canStraight && rng->bounded(100) < 74)
                    d = growDir;
                else
                    d = turnDirs.at(rng->bounded(turnDirs.size()));
                growDir = d;
                cur = QPoint(cur.x() + kDC[d], cur.y() + kDR[d]);
                path.prepend(cur);
            }

            if (!headLaneClear(head, headDir, path))
                continue;

            const int idx = m_arrows.size();
            for (const QPoint &p : path)
                occ[p.y() * cols + p.x()] = idx;
            m_arrows.push_back({ m_nextId++, path, headDir, false });
        }
    }

    // ── Stage 2: guarded tail-repair ──
    // Protect every cell on any snake's head-lane ray, then let tails absorb the
    // remaining empty cells.
    QSet<int> protectedCells;
    for (const Arrow &a : m_arrows) {
        const QPoint h = a.cells.last();
        int c = h.x() + kDC[a.dir], r = h.y() + kDR[a.dir];
        while (c >= 0 && c < cols && r >= 0 && r < rows) {
            protectedCells.insert(key(c, r));
            c += kDC[a.dir];
            r += kDR[a.dir];
        }
    }

    bool changed = true;
    while (changed) {
        changed = false;
        for (int i = 0; i < m_arrows.size(); ++i) {
            for (;;) {
                const QPoint t = m_arrows[i].cells.first();   // the tail
                QVector<QPoint> opts;
                for (int d = 0; d < 4; ++d) {
                    const QPoint n(t.x() + kDC[d], t.y() + kDR[d]);
                    if (isFree(n.x(), n.y()) && !protectedCells.contains(key(n.x(), n.y())))
                        opts.push_back(n);
                }
                if (opts.isEmpty())
                    break;
                const QPoint n = opts.at(rng->bounded(opts.size()));
                m_arrows[i].cells.prepend(n);
                occ[n.y() * cols + n.x()] = i;
                changed = true;
            }
        }
    }

    m_initial = m_arrows;
    m_initialCount = m_arrows.size();
    m_drops = m_maxDrops;
    m_status = Playing;
    rebuildOwner();
    endResetModel();

    emit boardChanged();
    emit dropsChanged();
    emit remainingChanged();
    emit statusChanged();
}

// ── Level flow ───────────────────────────────────────────────────────────────

void ArrowBoard::startLevel(int level)
{
    m_level = std::max(1, level);

    // The grid grows with the level (rectangular, portrait). Early levels are
    // small; later ones become large dense labyrinths that exceed the screen —
    // the board view is zoomable/pannable to accommodate them (as in the
    // reference, which has 500+ levels). Caps at 20×28 so generation stays quick.
    const int cols = std::clamp(6 + (m_level - 1) / 2, 6, 20);
    const int rows = std::clamp(cols + 8, 12, 28);

    generate(rows, cols);
    emit levelChanged();
}

void ArrowBoard::nextLevel()
{
    startLevel(m_level + 1);
}

void ArrowBoard::restart()
{
    beginResetModel();
    m_arrows = m_initial;
    m_drops = m_maxDrops;
    m_status = Playing;
    rebuildOwner();
    endResetModel();
    emit dropsChanged();
    emit remainingChanged();
    emit statusChanged();
}

void ArrowBoard::addLives()
{
    m_drops = m_maxDrops;
    emit dropsChanged();
    if (m_status == Lost)
        setStatus(Playing);
}

// ── Interaction ──────────────────────────────────────────────────────────────

void ArrowBoard::tap(int id)
{
    if (m_status != Playing)
        return;
    const int i = indexOfId(id);
    if (i < 0 || m_arrows[i].escaping)
        return;

    if (!laneClear(i)) {
        emit blocked(id);
        if (m_drops > 0) {
            --m_drops;
            emit dropsChanged();
            if (m_drops == 0)
                setStatus(Lost);
        }
        return;
    }

    // Launch: the snake stops blocking others immediately (its cells free up),
    // QML threads it off the board and calls finishEscape() when done.
    m_arrows[i].escaping = true;
    for (const QPoint &p : m_arrows[i].cells)
        m_owner.remove(key(p.x(), p.y()));

    const QModelIndex idx = index(i);
    emit dataChanged(idx, idx, { EscapingRole });
    emit escaped(id);
    emit remainingChanged();
}

void ArrowBoard::finishEscape(int id)
{
    const int i = indexOfId(id);
    if (i < 0)
        return;
    beginRemoveRows({}, i, i);
    m_arrows.remove(i);
    endRemoveRows();
    rebuildOwner();   // indices shifted; owner map must be rebuilt

    if (m_status == Playing && m_arrows.isEmpty())
        setStatus(Won);
}

int ArrowBoard::hint() const
{
    for (int i = 0; i < m_arrows.size(); ++i)
        if (!m_arrows.at(i).escaping && laneClear(i))
            return m_arrows.at(i).id;
    return -1;
}

void ArrowBoard::setStatus(Status s)
{
    if (m_status == s)
        return;
    m_status = s;
    emit statusChanged();
    if (s == Won)
        emit won();
    else if (s == Lost)
        emit lost();
}
