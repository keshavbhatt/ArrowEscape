#pragma once

#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

// PictureCatalog — loads the "Picture Pack" definitions bundled under
// :/data/pictures/*.json and tracks which pictures the player has completed
// (persisted via QSettings). Exposed to QML as a singleton-ish element.
//
// Each pack JSON: { id, name, pro, pictures:[ { id, name, mask:[ "..#..", ... ] } ] }.
// `mask` rows use '#'/'1' for filled cells. The catalog derives cols/rows and a
// stable per-picture RNG seed, and hands the whole thing to QML as `packs`.
class PictureCatalog : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList packs READ packs CONSTANT)
    Q_PROPERTY(QStringList completed READ completed NOTIFY completedChanged)

public:
    explicit PictureCatalog(QObject *parent = nullptr);

    QVariantList packs() const { return m_packs; }
    QStringList completed() const { return QStringList(m_completed.cbegin(), m_completed.cend()); }

    Q_INVOKABLE bool isCompleted(const QString &id) const { return m_completed.contains(id); }
    Q_INVOKABLE void markCompleted(const QString &id);

signals:
    void completedChanged();

private:
    void loadPacks();
    void loadCompleted();

    QVariantList  m_packs;
    QSet<QString> m_completed;
};
