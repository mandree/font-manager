
font_manager_gresource_xml_file = files('font-manager-gresources.xml')

font_manager_gresources = gnome.compile_resources('font-manager-gresources',
                                                  font_manager_gresource_xml_file)

result = run_command(python, '-c', list_vala_sources, check: true)
font_manager_sources = result.stdout().strip().split('\n')

dependencies = [ vapi, vala_deps ]

if get_option('adwaita')
    dependencies += adwaita
endif

if get_option('libarchive')
    dependencies += libarchive
endif

if get_option('webkit')
    dependencies += soup
    dependencies += webkit
endif

executable('font-manager',
            [font_manager_sources, font_manager_gresources, config_vapi],
            dependencies: dependencies,
            include_directories: includes,
            link_with: libfontmanager,
            link_whole: vala_common_library,
            install: true,
            install_rpath: pkglib_dir,
            # Silence warnings we can do nothing about.
            # These are expected in code generated by Vala.
            c_args: [ '-w' ])

includes += include_directories('.')

