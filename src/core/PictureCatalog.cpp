#include "PictureCatalog.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>

PictureCatalog::PictureCatalog(QObject *parent)
    : QObject(parent)
{
    loadCompleted();
    loadPacks();
}

void PictureCatalog::loadPacks()
{
    const QDir dir(QStringLiteral(":/data/pictures"));
    const QStringList files = dir.entryList({ QStringLiteral("*.json") }, QDir::Files, QDir::Name);

    for (const QString &fileName : files) {
        QFile f(dir.filePath(fileName));
        if (!f.open(QIODevice::ReadOnly))
            continue;
        const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();

        QVariantMap pack;
        pack.insert(QStringLiteral("id"),   root.value(QStringLiteral("id")).toString());
        pack.insert(QStringLiteral("name"), root.value(QStringLiteral("name")).toString());
        pack.insert(QStringLiteral("pro"),  root.value(QStringLiteral("pro")).toBool());

        QVariantList pics;
        const QJsonArray arr = root.value(QStringLiteral("pictures")).toArray();
        for (const QJsonValue &pv : arr) {
            const QJsonObject po = pv.toObject();
            QStringList mask;
            for (const QJsonValue &row : po.value(QStringLiteral("mask")).toArray())
                mask << row.toString();
            const int rows = mask.size();
            const int cols = rows > 0 ? int(mask.first().size()) : 0;
            const QString id = po.value(QStringLiteral("id")).toString();

            QVariantMap pic;
            pic.insert(QStringLiteral("id"),   id);
            pic.insert(QStringLiteral("name"), po.value(QStringLiteral("name")).toString());
            pic.insert(QStringLiteral("mask"), mask);
            pic.insert(QStringLiteral("cols"), cols);
            pic.insert(QStringLiteral("rows"), rows);
            // Stable per-picture seed so a given picture always generates the same board.
            pic.insert(QStringLiteral("seed"), int(qHash(id) & 0x7fffffff));
            pics.push_back(pic);
        }
        pack.insert(QStringLiteral("pictures"), pics);
        m_packs.push_back(pack);
    }
}

void PictureCatalog::loadCompleted()
{
    QSettings s;
    s.beginGroup(QStringLiteral("pictures"));
    const QStringList done = s.value(QStringLiteral("completed")).toStringList();
    s.endGroup();
    m_completed = QSet<QString>(done.cbegin(), done.cend());
}

void PictureCatalog::markCompleted(const QString &id)
{
    if (id.isEmpty() || m_completed.contains(id))
        return;
    m_completed.insert(id);

    QSettings s;
    s.beginGroup(QStringLiteral("pictures"));
    s.setValue(QStringLiteral("completed"), completed());
    s.endGroup();

    emit completedChanged();
}
