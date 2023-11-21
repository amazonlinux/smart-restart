Name:           smart-restart
Version:        0.1
Release:        1%{?dist}
Summary:        Restarts services after the libs they link against have changed.

License:        Apache 2.0

%if "%{dist}" == ".amzn2023"
Requires:       dnf-utils 
Requires:       dnf-plugin-post-transaction-actions
%define         _plugin_path dnf/plugins/post-transaction-actions.d/
%else
%if "%{dist}" == ".amzn2"
Requires:       yum-utils 
Requires:       yum-plugin-post-transaction-actions
%define         _plugin_path yum/post-actions/
%else
%{error Distribution "%{expand:%{?dist}}" not supported}
%endif
%endif

Source:         %{name}-%{version}-%{release}.tar.gz
%description    
Hooks dnf and automatically restarts services after updates to their dependencies

%prep
%setup -n %{name}-%{version}-%{release}

$install
# The makefile uses DNF as the default package manager, we can override with yum using PKG_MANAGER=yum
make DEST_DIR=$RPM_BUILD_ROOT DIST=%{?dist} PREFIX=%{_bindir} install


%files
%defattr(-,root,root,-)
%{_bindir}/%{name}.sh
%config %{_sysconfdir}/%{_plugin_path}/install.action
%config %{_sysconfdir}/smart-restart-conf.d/default-denylist
%doc /usr/share/man/man1/smart-restart.man1

# Update man db 
# %post
# /usr/bin/mandb


