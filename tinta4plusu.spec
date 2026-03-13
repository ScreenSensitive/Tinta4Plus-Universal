# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec for Tinta4PlusU GUI
Produces: dist/tinta4plusu/tinta4plusu
"""

from PyInstaller.utils.hooks import collect_data_files

# sv_ttk ships TCL/TK theme files that must be bundled
sv_ttk_datas = []
try:
    sv_ttk_datas = collect_data_files('sv_ttk')
except Exception:
    pass

a = Analysis(
    ['Tinta4Plus.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('eink-disable1.jpg', '.'),
        ('eink-disable2.jpg', '.'),
        ('eink-disable3.jpg', '.'),
        ('README_EULA_INSTRUCTIONS_WARNINGS.txt', '.'),
    ] + sv_ttk_datas,
    hiddenimports=[
        'ThemeManager',
        'DisplayManager',
        'HelperClient',
        'ResumeCheck',
        'sv_ttk',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='tinta4plusu',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='tinta4plusu',
)
