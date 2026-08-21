%define _trivial	.0
%define _buildid	.3
Name:           smart-restart
Version:        0.2
Release:        1%{?dist}
Summary:        Restarts services after the libs they link against have changed.

License:        Apache 2.0

%if 0%{?amzn2}
%bcond_without yum
%else
%bcond_with yum
%endif

%if %{with yum}
Requires:       yum-utils 
Requires:       yum-plugin-post-transaction-actions
%define         _plugin_path yum/post-actions/
%define         _hook_file install.action
%define         pkg_manager yum
%elif 0%{?amzn} >= 2027
# dnf5-only. needs-restarting is the dnf5 subcommand from dnf5-plugins,
# and the post-transaction hook runs through the libdnf5 actions plugin
# instead of dnf4's post-transaction-actions plugin.
Requires:       dnf5-plugins
Requires:       libdnf5-plugin-actions
%define         _plugin_path dnf/libdnf5-plugins/actions.d/
%define         _hook_file smart-restart.actions
%define         pkg_manager dnf5
%else
Requires:       dnf-utils
Requires:       dnf-plugin-post-transaction-actions
%define         _plugin_path dnf/plugins/post-transaction-actions.d/
%define         _hook_file install.action
%define         pkg_manager dnf
%endif


URL:            https://github.com/amazonlinux/smart-restart/archive/v%{version}/
Source0:        %{name}-v%{version}.tar.gz

%description    
Hooks dnf/yum and automatically restarts services after updates to their dependencies

%prep
%autosetup -n %{name}-v%{version}

%install
make DEST_DIR=$RPM_BUILD_ROOT pkg_manager=%{pkg_manager} PREFIX=%{_bindir} install


%files
%defattr(-,root,root,-)
%{_bindir}/%{name}.sh
%config %{_sysconfdir}/%{_plugin_path}/%{_hook_file}
%config %{_sysconfdir}/smart-restart-conf.d/default-denylist
%doc %{_mandir}/man1/smart-restart.1*

%changelog
* Wed Mar 06 2024 Stanislav Uschakow <suschako@amazon.de> - 0.1-1.amzn2023.0.1
- Initial release of smart-restart-v0.1-1 for al2023

