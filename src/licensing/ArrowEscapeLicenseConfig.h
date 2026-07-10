#pragma once

#include "AccountLicenseConfig.h"

#include <QCoreApplication>
#include <QStringLiteral>

/**
 * @brief AccountLicenseConfig for ArrowEscape.
 *
 * A thin client over the shared ktechpit "USS" backend, keyed by
 * @c slug=arrowescape. Mirrors the sibling apps (TypingMaster, etc.).
 */
inline AccountLicenseConfig arrowEscapeLicenseConfig()
{
    AccountLicenseConfig cfg;

    cfg.appCode = QStringLiteral("AE");
    cfg.appName = QStringLiteral("ArrowEscape");

    // Must match QGuiApplication::setOrganizationName / setApplicationName.
    cfg.settingsOrgName = QCoreApplication::organizationName();
    cfg.settingsAppName = QCoreApplication::applicationName();

    cfg.checkStatusEndpoint =
        QStringLiteral("https://ktechpit.com/USS/public/check/status.php");
    cfg.checkoutUrlTemplate = QStringLiteral(
        "https://ktechpit.com/USS/public/checkout.php?slug=arrowescape&accountId=%1");
    cfg.selfServicePortalUrl =
        QStringLiteral("https://ktechpit.com/USS/public/user/");

    // 10-day full-featured trial (Pro unlocked during the evaluation).
    cfg.evaluationDurationSecs = 10LL * 24LL * 60LL * 60LL;

    return cfg;
}
