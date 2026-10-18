# Configuration file for the Sphinx documentation builder.
# crystal-dbus-native: Native D-Bus Wire Protocol Shard for Crystal

project = 'crystal-dbus-native'
copyright = '2026, Rénich Bon Ćirić (Copyleft)'
author = 'Rénich Bon Ćirić'
release = '0.3.1'

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',
    'sphinx.ext.todo',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'build', 'technical/api', 'Thumbs.db', '.DS_Store']

html_theme = 'sphinx_rtd_theme'
html_static_path = []
html_title = 'Crystal D-Bus Native Documentation'
html_show_sourcelink = False
