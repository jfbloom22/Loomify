# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='main',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
app = BUNDLE(
    exe,
    name='main.app',
    icon=None,  # Add path to your .icns file if you have a custom icon
    bundle_identifier='com.jonathanflower.loomify',
    info_plist={
        "CFBundleName": "loomify",
        "CFBundleDisplayName": "loomify",
        "CFBundleIdentifier": "com.jonathanflower.loomify",
        "CFBundleVersion": "1.0",
        "CFBundleShortVersionString": "1.0",
        "CFBundleExecutable": "main",
        "CFBundleDocumentTypes": [
            {
                "CFBundleTypeName": "Video File",
                "CFBundleTypeRole": "Viewer",
                "LSItemContentTypes": ["public.movie", "public.video"],
            }
        ],
    },
)