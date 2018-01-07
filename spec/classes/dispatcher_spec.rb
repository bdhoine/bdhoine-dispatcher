require 'spec_helper'

describe 'dispatcher' do
  on_supported_os.each do |os, os_facts|
    context "on #{os} #" do

      let(:pre_condition) do
        'class { "apache" :
          default_vhost    => false,
          default_mods     => false,
        }'
      end

      let (:default_params) do
        {
          module_file: '/tmp/dispatcher-apache.so'
        }
      end

      let(:params) { default_params }

      let(:facts) { os_facts }

      case os_facts[:os]['family']
      when 'RedHat'
        log_path = '/var/log/httpd'
        mod_path = '/etc/httpd/modules'
        if os_facts[:os]['release']['major'].to_i >= 7
          farm_path = '/etc/httpd/conf.modules.d'
        else
          farm_path = '/etc/httpd/conf.d'
        end
      when 'Debian'
        log_path = '/var/log/apache2'
        mod_path = '/usr/lib/apache2/modules'
        farm_path = '/etc/apache2/mods-enabled'
      end

      context 'default parameters' do
        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_class('dispatcher').with(
            'ensure'            => 'present',
            'config_file'       => 'dispatcher.farms.any',
            'decline_root'      => 'off',
            'group'             => 'root',
            'log_file'          => "#{log_path}/dispatcher.log",
            'log_level'         => 'warn',
            'module_file'       => '/tmp/dispatcher-apache.so',
            'no_server_header'  => 'off',
            'pass_error'        => '0',
            'use_processed_url' => 'off',
            'user'              => 'root'
          )
        end

        it do
          is_expected.to contain_file("#{mod_path}/dispatcher-apache.so").with(
            'ensure'  => 'file',
            'path'    => "#{mod_path}/dispatcher-apache.so",
            'group'   => 'root',
            'owner'   => 'root',
            'replace' => 'true',
            'source'  => '/tmp/dispatcher-apache.so'
          )
        end

        it do
          is_expected.to contain_file("#{mod_path}/mod_dispatcher.so").with(
            'ensure'  => 'link',
            'path'    => "#{mod_path}/mod_dispatcher.so",
            'group'   => 'root',
            'owner'   => 'root',
            'replace' => 'true',
            'target'  => "#{mod_path}/dispatcher-apache.so"
          )
        end

        it do
          is_expected.to contain_file("#{farm_path}/dispatcher.conf").with(
            'ensure'  => 'file',
            'path'    => "#{farm_path}/dispatcher.conf",
            'group'   => 'root',
            'owner'   => 'root',
            'replace' => 'true'
          ).with_content(
            %r|.*DispatcherConfig\s*#{farm_path}/dispatcher.farms.any|
          ).with_content(
            %r|.*DispatcherLog\s*#{log_path}/dispatcher.log|
          ).with_content(
            /.*DispatcherLogLevel\s*warn/
          ).with_content(
            /.*DispatcherDeclineRoot\s*off/
          ).with_content(
            /.*DispatcherUseProcessedURL\s*off/
          ).with_content(
            /.*DispatcherPassError\s*0/
          )
        end

        it do
          is_expected.to contain_file(
            "#{mod_path}/dispatcher-apache.so"
          )
        end

        it do
          is_expected.to contain_file(
            "#{mod_path}/mod_dispatcher.so"
          ).that_requires(
            "File[#{mod_path}/dispatcher-apache.so]"
          )
        end

        it do
          is_expected.to contain_apache__mod(
            'dispatcher'
          ).that_requires(
            "File[#{mod_path}/mod_dispatcher.so]"
          )
        end
        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.farms.any"
          ).that_requires(
            'Apache::Mod[dispatcher]'
          )
        end

        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.conf"
          ).that_requires(
            "File[#{farm_path}/dispatcher.farms.any]"
          )
        end

        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.conf"
          ).that_notifies(
            'Service[httpd]'
          )
        end

        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.farms.any"
          ).that_notifies(
            'Service[httpd]'
          )
        end
      end

      describe 'parameter validation' do
        context 'ensure' do
          context 'should accept present' do
            let(:params) do
              default_params.merge(ensure: 'present')
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept absent' do
            let(:params) do
              default_params.merge(ensure: 'absent')
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should not accept any other value' do
            let(:params) do
              default_params.merge(ensure: 'invalid')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

        end

        context 'decline_root' do
          context 'numeric' do
            context 'should accept 0' do
              let(:params) do
                default_params.merge(decline_root: 0)
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should accept 1' do
              let(:params) do
                default_params.merge(decline_root: 1)
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any other positive value' do
              let(:params) do
                default_params.merge(decline_root: 2)
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end

            context 'should not accept any negative value' do
              let(:params) do
                default_params.merge(decline_root: -1)
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end
          end

          context 'named values' do
            context 'should accept on' do
              let(:params) do
                default_params.merge(decline_root: 'on')
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should accept off' do
              let(:params) do
                default_params.merge(decline_root: 'off')
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any other value' do
              let(:params) do
                default_params.merge(decline_root: 'invalid')
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end
          end
        end

        context 'log_level' do
          context 'numeric' do
            context 'should accept 0' do
              let(:params) do
                default_params.merge(log_level: 0)
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept 1' do
              let(:params) do
                default_params.merge(log_level: 1)
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept 2' do
              let(:params) do
                default_params.merge(log_level: 2)
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept 3' do
              let(:params) do
                default_params.merge(log_level: 3)
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept 4' do
              let(:params) do
                default_params.merge(log_level: 4)
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any other positive value' do
              let(:params) do
                default_params.merge(log_level: 5)
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end
            context 'should not accept any negative value' do
              let(:params) do
                default_params.merge(log_level: -1)
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end
          end

          context 'named values' do
            context 'should accept error' do
              let(:params) do
                default_params.merge(log_level: 'error')
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept warn' do
              let(:params) do
                default_params.merge(log_level: 'warn')
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept info' do
              let(:params) do
                default_params.merge(log_level: 'info')
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept debug' do
              let(:params) do
                default_params.merge(log_level: 'debug')
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept trace' do
              let(:params) do
                default_params.merge(log_level: 'trace')
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any other value' do
              let(:params) do
                default_params.merge(log_level: 'invalid')
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end
          end
        end

        context 'use_processed_url' do
          context 'numeric' do
            context 'should accept 0' do
              let(:params) do
                default_params.merge(use_processed_url: 0)
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept 1' do
              let(:params) do
                default_params.merge(use_processed_url: 1)
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any other positive value' do
              let(:params) do
                default_params.merge(use_processed_url: 2)
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end
            context 'should not accept any negative value' do
              let(:params) do
                default_params.merge(use_processed_url: -1)
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end
          end

          context 'named values' do
            context 'should accept on' do
              let(:params) do
                default_params.merge(use_processed_url: 'on')
              end
              it { is_expected.to compile.with_all_deps }
            end
            context 'should accept off' do
              let(:params) do
                default_params.merge(use_processed_url: 'off')
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any other value' do
              let(:params) do
                default_params.merge(use_processed_url: 'invalid')
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end
          end
        end
      end

      context 'apache not managed' do
        let(:params) do
          default_params.merge(ensure: 'present')
        end
        let(:pre_condition) do
          'class { "apache" :
            default_vhost    => false,
            default_mods     => false,
            service_manage   => false,
            vhost_enable_dir => "/etc/apache2/sites-enabled"
          }'
        end

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to contain_class('dispatcher').with(
            'ensure'            => 'present',
            'decline_root'      => 'off',
            'group'             => 'root',
            'log_file'          => "#{log_path}/dispatcher.log",
            'log_level'         => 'warn',
            'module_file'       => '/tmp/dispatcher-apache.so',
            'pass_error'        => '0',
            'use_processed_url' => 'off',
            'user'              => 'root'
          )
        end

        it do
          is_expected.to contain_file("#{mod_path}/dispatcher-apache.so").with(
            'ensure'  => 'file',
            'path'    => "#{mod_path}/dispatcher-apache.so",
            'group'   => 'root',
            'owner'   => 'root',
            'replace' => 'true',
            'source'  => '/tmp/dispatcher-apache.so'
          )
        end

        it do
          is_expected.to contain_file("#{mod_path}/mod_dispatcher.so").with(
            'ensure'  => 'link',
            'path'    => "#{mod_path}/mod_dispatcher.so",
            'group'   => 'root',
            'owner'   => 'root',
            'replace' => 'true',
            'target'  => "#{mod_path}/dispatcher-apache.so"
          )
        end

        it do
          is_expected.to contain_file("#{farm_path}/dispatcher.conf").with(
            'ensure'  => 'file',
            'path'    => "#{farm_path}/dispatcher.conf",
            'group'   => 'root',
            'owner'   => 'root',
            'replace' => 'true'
          ).with_content(
            %r|.*DispatcherConfig\s*#{farm_path}/dispatcher.farms.any|
          ).with_content(
            %r|.*DispatcherLog\s*#{log_path}/dispatcher.log|
          ).with_content(
            /.*DispatcherLogLevel\s*warn/
          ).with_content(
            /.*DispatcherDeclineRoot\s*off/
          ).with_content(
            /.*DispatcherUseProcessedURL\s*off/
          ).with_content(
            /.*DispatcherPassError\s*0/
          )
        end

        it do
          is_expected.to contain_file(
            "#{mod_path}/dispatcher-apache.so"
          )
        end

        it do
          is_expected.to contain_file(
            "#{mod_path}/mod_dispatcher.so"
          ).that_requires(
            "File[#{mod_path}/dispatcher-apache.so]"
          )
        end

        it do
          is_expected.to contain_apache__mod(
            'dispatcher'
          ).that_requires(
            "File[#{mod_path}/mod_dispatcher.so]"
          )
        end
        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.farms.any"
          ).that_requires(
            'Apache::Mod[dispatcher]'
          )
        end

        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.conf"
          ).that_requires(
            "File[#{farm_path}/dispatcher.farms.any]"
          )
        end
      end

      context 'ensure absent' do
        let(:params) do
          default_params.merge(ensure: 'absent')
        end

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to contain_class('dispatcher').with(
            'ensure'            => 'absent',
            'decline_root'      => 'off',
            'group'             => 'root',
            'log_file'          => "#{log_path}/dispatcher.log",
            'log_level'         => 'warn',
            'module_file'       => '/tmp/dispatcher-apache.so',
            'pass_error'        => '0',
            'use_processed_url' => 'off',
            'user'              => 'root'
          )
        end

        it do
          is_expected.to contain_file(
            "#{mod_path}/dispatcher-apache.so"
          ).with(
            'ensure' => 'absent'
          )
        end

        it do
          is_expected.to contain_file(
            "#{mod_path}/mod_dispatcher.so"
          ).with(
            'ensure' => 'absent'
          )
        end

        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.conf"
          ).with(
            'ensure' => 'absent'
          )
        end

        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.conf"
          )
        end
        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.farms.any"
          ).that_requires(
            "File[#{farm_path}/dispatcher.conf]"
          )
        end
        it do
          is_expected.to contain_file(
            "#{mod_path}/dispatcher-apache.so"
          ).that_requires(
            "File[#{farm_path}/dispatcher.farms.any]"
          )
        end

        it do
          is_expected.to contain_file(
            "#{mod_path}/mod_dispatcher.so"
          ).that_requires(
            "File[#{farm_path}/dispatcher.conf]"
          )
        end

        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.farms.any"
          ).that_notifies(
            'Service[httpd]'
          )
        end
        it do
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.conf"
          ).that_notifies(
            'Service[httpd]'
          )
        end
      end

      context 'selinux enabled' do
        let(:facts) do
          os_facts.merge(
            {
              selinux: true
            }
          )
        end

        it { is_expected.to compile.with_all_deps }

        it do
          is_expected.to contain_file(
            "#{mod_path}/dispatcher-apache.so"
          ).with(
            'seltype' => 'httpd_modules_t'
          )
        end

        it do
          is_expected.to contain_file(
            "#{mod_path}/mod_dispatcher.so"
          ).with(
            'seltype' => 'httpd_modules_t'
          )
        end

        it do
          is_expected.to contain_selboolean('httpd_can_network_connect').with(
            'value'      => 'on',
            'persistent' => true
          )
        end
      end
    end
  end
end
