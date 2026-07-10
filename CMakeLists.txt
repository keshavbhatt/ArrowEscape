cmake_minimum_required(VERSION 3.21)

project(ArrowEscape
    VERSION 0.1.0
    DESCRIPTION "A calm slide-the-arrows-off-the-board puzzle for the desktop"
    HOMEPAGE_URL "https://ktechpit.com"
    LANGUAGES CXX)

# ── Single source of truth for the reverse-DNS app id ─────────────────────────
set(AE_APP_ID   "com.ktechpit.arrowescape")
set(AE_APP_NAME "ArrowEscape")

# ── Project-wide build settings ───────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
        Debug Release RelWithDebInfo MinSizeRel)
endif()

# ── Qt ── (pure Qt Quick app: no Widgets) ─────────────────────────────────────
find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core Gui Qml Quick QuickControls2 Svg Multimedia)

qt_standard_project_setup(REQUIRES 6.5)

# Auto-generate qmldir entries for QML files kept in subdirectories.
qt_policy(SET QTP0004 NEW)

# ── Configured build metadata header (app id / name / version) ────────────────
configure_file(src/AppInfo.h.in ${CMAKE_BINARY_DIR}/generated/AppInfo.h @ONLY)

# ── Executable ────────────────────────────────────────────────────────────────
qt_add_executable(arrowescape
    src/main.cpp
)

# QML files physically live under src/qml/. Alias each into the module root so
# compiled resource paths stay clean (e.g. Main.qml, components/Hearts.qml).
set(AE_QML_FILES
    Main.qml
    Theme.qml
    Board.qml
    ArrowSnake.qml
    LevelSelect.qml
    HomeScreen.qml
    components/PicturePreview.qml
    components/Drops.qml
    components/Icon.qml
    components/IconButton.qml
    components/PillButton.qml
)
set(AE_QML_PATHS "")
foreach(qml IN LISTS AE_QML_FILES)
    set(path "src/qml/${qml}")
    set_source_files_properties(${path} PROPERTIES QT_RESOURCE_ALIAS ${qml})
    list(APPEND AE_QML_PATHS ${path})
endforeach()

# Theme.qml is a `pragma Singleton`; mark it explicitly (setting QT_RESOURCE_ALIAS
# above suppresses auto-detection).
set_source_files_properties(src/qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# ── QML module (compiles QML, registers C++ QML_ELEMENT types under the URI) ──
qt_add_qml_module(arrowescape
    URI ArrowEscape
    VERSION 1.0
    QML_FILES ${AE_QML_PATHS}
    SOURCES
        src/core/ArrowBoard.h      src/core/ArrowBoard.cpp
        src/core/PictureCatalog.h  src/core/PictureCatalog.cpp
)

# ── Bundled assets: app icon + sound effects ──────────────────────────────────
file(GLOB_RECURSE AE_SOUND_FILES CONFIGURE_DEPENDS
     RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/sounds/*.wav)

# Picture Pack definitions (Collections). Dropping a new pack JSON in and
# rebuilding is all it takes — PictureCatalog scans them at runtime.
file(GLOB AE_PICTURE_FILES CONFIGURE_DEPENDS
     RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} data/pictures/*.json)

qt_add_resources(arrowescape "appdata"
    PREFIX "/"
    BASE ${CMAKE_CURRENT_SOURCE_DIR}
    FILES
        assets/icons/${AE_APP_ID}.svg
        ${AE_SOUND_FILES}
        ${AE_PICTURE_FILES}
)

target_include_directories(arrowescape PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core
    ${CMAKE_BINARY_DIR}/generated
)

target_link_libraries(arrowescape PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Svg
    Qt6::Multimedia
)

target_compile_definitions(arrowescape PRIVATE
    $<$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>,$<CONFIG:MinSizeRel>>:QT_NO_DEBUG_OUTPUT>
    # Debug-only testing aids (level jumper, unlock-all). Never defined in release.
    $<$<CONFIG:Debug>:AE_DEBUG>
)

# ── Install (desktop integration) ─────────────────────────────────────────────
include(GNUInstallDirs)

install(TARGETS arrowescape RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES packaging/${AE_APP_ID}.desktop
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)

# AppStream metainfo — snapcraft's parse-info pulls the summary/description/
# licence from here so they need not be repeated in snapcraft.yaml.
install(FILES packaging/${AE_APP_ID}.metainfo.xml
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/metainfo)

install(FILES assets/icons/${AE_APP_ID}.svg
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps)
