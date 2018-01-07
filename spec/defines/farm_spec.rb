require 'spec_helper'

describe 'dispatcher::farm' do
  on_supported_os.each do |os, os_facts|
    context "on #{os} #{os_facts['operatingsystemrelease']}" do
      let(:pre_condition) do
        'class { "apache":
          default_vhost => false,
          default_mods  => false,
        }
        class { "dispatcher":
          module_file => "/tmp/module.so"
        }'
      end

      let(:title) { 'aem-site' }

      let(:default_params) do
        {
          'docroot' => '/path/to/docroot'
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
          is_expected.to contain_file(
            "#{farm_path}/dispatcher.00-#{title}.inc.any"
          ).with(
            'ensure' => 'present'
          ).with_content(
            %r|/aem-site {|
          ).without_content(
            /allowAuthorized/
          ).with_content(
            %r|/allowedClients {\s*/0 { /type "allow" /glob "\*" }\s*}|
          ).with_content(
            %r|/clientheaders {\s*"\*"\s*}|
          ).with_content(
            %r|/docroot \s*"/path/to/docroot"\s*|
          ).without_content(
            /enableTTL/
          ).without_content(
            /gracePeriod/
          ).without_content(
            %r|/headers|
          ).without_content(
            /failover/
          ).without_content(
            /health_check/
          ).without_content(
            /ignoreUrlParameters/
          ).with_content(
            %r|/invalidate {\s*/0 \{ /type "allow" /glob "\*" }|
          ).without_content(
            /invalidateHandler/
          ).with_content(
            %r|/filter {\s*/0 { /type "allow" /glob "\*" }|
          ).without_content(
            /numberOfRetries/
          ).with_content(
            %r|/renders {\s*/renderer0 {\s*/hostname "localhost"\s*/port "4503"\s*}|
          ).without_content(
            /retryDelay/
          ).with_content(
            %r|/rules {\s*/0 { /type "deny" /glob "\*" }|
          ).without_content(
            /serveStaleOnError/
          ).without_content(
            /sessionmanagement/
          ).without_content(
            /statfile/
          ).without_content(
            /statfileslevel/
          ).without_content(
            /statistics/
          ).without_content(
            /stickyConnections/
          ).without_content(
            /unavailablePenalty/
          ).without_content(
            /vanity_urls/
          ).with_content(
            %r|/virtualhosts {\s*"\*"\s*}|
          )
        end
      end

      context 'parameter' do
        context 'ensure' do
          context 'should accept present' do
            let(:params) do
              default_params.merge(ensure: 'present')
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with(
                'ensure' => 'present'
              ).that_notifies(
                'Service[httpd]'
              )
            end
          end

          context 'should accept absent' do
            let(:params) do
              default_params.merge(ensure: 'absent')
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with(
                'ensure' => 'absent'
              ).that_notifies(
                'Service[httpd]'
              )
            end
          end

          context 'should not accept invalid' do
            let(:params) do
              default_params.merge(ensure: 'invalid')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'allow_authorized' do
          context 'should accept 0' do
            let(:params) do
              default_params.merge(allow_authorized: 0)
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept 1' do
            let(:params) do
              default_params.merge(allow_authorized: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/allowAuthorized "1"|
              )
            end
          end

          context 'should not accept any other positive value' do
            let(:params) do
              default_params.merge(allow_authorized: 2)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(allow_authorized: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'allowed_clients' do
          context 'should not accept a single hash' do
            let(:params) do
              default_params.merge(allowed_clients: { 'glob' => '*', 'type' => 'allow' })
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should accept an array of hashes' do
            let(:params) do
              default_params.merge(
                allowed_clients: [
                  { 'glob' => '*', 'type' => 'deny' },
                  { 'glob' => 'localhost', 'type' => 'allow' }
                ]
              )
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should not accept a string' do
            let(:params) do
              default_params.merge(allowed_clients: 'not a hash')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'require arrays contain a hash' do
            let(:params) do
              default_params.merge(allowed_clients: ['not a hash', 'another non hash'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should require a value' do
            let(:params) do
              default_params.merge(allowed_clients: nil)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should respect rank' do
            let(:params) do
              default_params.merge(
                allowed_clients: [
                  { 'rank' => 100, 'glob' => '10.200.1.1', 'type' => 'allow' },
                  { 'glob' => '*', 'type' => 'deny' }
                ]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/allowedClients {\s*/0 { /type "deny" /glob "\*" }\s*/1 { /type "allow" /glob "10.200.1.1" }\s*}|
              )
            end
          end
        end

        context 'cache_headers' do
          context 'should not accept a single value' do
            let(:params) do
              default_params.merge(cache_headers: 'A-Cache-Header')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should accept an array of values' do
            let(:params) do
              default_params.merge(cache_headers: ['A-Cache-Header', 'Another-Cache-Header'])
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/headers {\s*"A-Cache-Header"\s*"Another-Cache-Header"\s*}|
              )
            end
          end
        end

        context 'cache_rules' do
          context 'should not accept a single hash' do
            let(:params) do
              default_params.merge(cache_rules: { 'glob' => '*', 'type' => 'deny' })
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should accept an array of hashes' do
            let(:params) do
              default_params.merge(
                cache_rules: [
                  { 'glob' => '*', 'type' => 'deny' },
                  { 'glob' => '*.html', 'type' => 'allow' }
                ]
              )
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should not accept a string' do
            let(:params) do
              default_params.merge(cache_rules: 'not a hash')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'require arrays contain a hash' do
            let(:params) do
              default_params.merge(cache_rules: ['not a hash', 'another non hash'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should require a value' do
            let(:params) do
              default_params.merge(cache_rules: nil)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should respect rank' do
            let(:params) do
              default_params.merge(
                cache_rules: [
                  { 'rank' => 200, 'glob' => '*.html', 'type' => 'allow' },
                  { 'glob' => '*', 'type' => 'deny' }
                ]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/rules {\s*/0 { /type "deny" /glob "\*" }\s*/1 { /type "allow" /glob "\*.html" }|
              )
            end
          end
        end

        context 'cache_ttl' do
          context 'should accept 0' do
            let(:params) do
              default_params.merge(cache_ttl: 0)
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept 1' do
            let(:params) do
              default_params.merge(cache_ttl: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/enableTTL "1"\s*|
              )
            end
          end

          context 'should not accept any other positive value' do
            let(:params) do
              default_params.merge(cache_ttl: 2)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(cache_ttl: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'client_headers' do
          context 'should not accept a single value' do
            let(:params) do
              default_params.merge(client_headers: 'A-Client-Header')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should accept an array of values' do
            let(:params) do
              default_params.merge(client_headers: ['A-Client-Header', 'Another-Client-Header'])
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/clientheaders {\s*"A-Client-Header"\s*"Another-Client-Header"\s*}|
              )
            end
          end
        end

        context 'docroot' do
          context 'should be required' do
            let(:params) do
              {
                'notdocroot' => '/path/to/docroot'
              }
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept a relative path' do
            let(:params) do
              default_params.merge(docroot: 'relative/path')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'failover' do
          context 'should accept 0' do
            let(:params) do
              default_params.merge(failover: 0)
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept 1' do
            let(:params) do
              default_params.merge(failover: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/failover "1"\s*|
              )
            end
          end

          context 'should not accept any other positive value' do
            let(:params) do
              default_params.merge(failover: 2)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(failover: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'filters' do
          context 'should accept an array of hashes' do
            let(:params) do
              default_params.merge(
                filters: [
                  { 'glob' => '*', 'type' => 'deny' },
                  { 'glob' => '* /content*', 'type' => 'allow' }
                ]
              )
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'require arrays contain a hash' do
            let(:params) do
              default_params.merge(filters: ['not a hash', 'another non hash'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should require a value' do
            let(:params) do
              default_params.merge(filters: nil)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should respect rank' do
            let(:params) do
              default_params.merge(
                filters: [
                  { 'rank' => 10, 'type' => 'allow', 'glob' => '/content*' },
                  { 'type' => 'deny', 'glob' => '*' }
                ]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/filter {\s*/0 { /type "deny" /glob "\*" }\s*/1 { /type "allow" /glob "/content\*" }|
              )
            end
          end

          context 'with filter glob' do
            let(:params) do
              default_params.merge(filters: [{ 'type' => 'deny', 'glob' => '/content*' }])
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/filter {\s*/0 { /type "deny" /glob "/content\*" }|
              )
            end
          end

          context 'with all request filter line values' do
            let(:params) do
              default_params.merge(
                filters: [{
                  'type'      => 'allow',
                  'method'    => 'GET',
                  'url'       => '/path/to/content',
                  'query'     => 'param=*',
                  'protocol'  => 'https',
                  'path'      => '/different/path/to/content',
                  'selectors' => '\'((sys|doc)view|query|[0-9-]+)\'',
                  'extension' => '\'(css|gif|ico|js|png|swf|jpe?g)\'',
                  'suffix'    => '\'/suffix/path\''
                }]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /0\s{\s*
                    /type\s"allow"\s*
                    /method\s"GET"\s*
                    /url\s"/path/to/content"\s*
                    /query\s"param=\*"\s*
                    /protocol\s"https"\s*
                    /path\s"/different/path/to/content"\s*
                    /selectors\s'\(\(sys\|doc\)view\|query\|\[0-9-\]\+\)'\s*
                    /extension\s'\(css\|gif\|ico\|js\|png\|swf\|jpe\?g\)'\s*
                    /suffix\s\'/suffix/path\'\s*
                  }
                |x
              )
            end

            context 'with method only' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'   => 'allow',
                    'method' => 'GET'
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/method\s*"GET"\s*}|
                )
              end
            end

            context 'with method regex' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'   => 'allow',
                    'method' => '\'(GET|HEAD)\''
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/method\s*\'\(GET\|HEAD\)\'\s*}|
                )
              end
            end

            context 'with url value' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type' => 'allow',
                    'url'  => '/path/to/content'
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/url\s*"/path/to/content"\s*}|
                )
              end
            end

            context 'with url regex' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type' => 'allow',
                    'url'  => '\'/path/to/(content|lib)/?\''
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/url\s*\'/path/to/\(content\|lib\)/\?\'\s*}|
                )
              end
            end

            context 'with query' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'     => 'allow',
                    'query'    => 'param=*'
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/query\s*"param=\*"\s*}|
                )
              end
            end

            context 'with query regex' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'     => 'allow',
                    'query'    => '\'param=.*\''
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/query\s*\'param=\.\*\'\s*}|
                )
              end
            end

            context 'with protocol' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'     => 'allow',
                    'protocol' => 'https'
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/protocol\s"https"\s*}|
                )
              end
            end

            context 'with protocol regex' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'     => 'allow',
                    'protocol' => '\'https?\''
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/protocol\s\'https\?\'\s*}|
                )
              end
            end

            context 'with path' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type' => 'allow',
                    'path' => '/path/to/content'
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/path\s*"/path/to/content"\s*}|
                )
              end
            end

            context 'with path regex' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type' => 'allow',
                    'path' => '\'/path/to/(content|lib)/?\''
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/path\s*\'/path/to/\(content\|lib\)/\?\'\s*}|
                )
              end
            end

            context 'with selectors' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'      => 'allow',
                    'selectors' => 'thumb'
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/selectors\s"thumb"\s*}|
                )
              end
            end

            context 'with selectors regex' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'      => 'allow',
                    'selectors' => '\'[0-9]+\''
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/selectors\s\'\[0-9\]\+\'\s*}|
                )
              end
            end

            context 'with extension' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'      => 'allow',
                    'extension' => 'ico'
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/extension\s"ico"\s*}|
                )
              end
            end

            context 'with extension regex' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'      => 'allow',
                    'extension' => '\'(ico|png)\''
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/extension\s\'\(ico\|png\)\'\s*}|
                )
              end
            end

            context 'with suffix' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'   => 'allow',
                    'suffix' => '/suffix/path'
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/suffix\s"/suffix/path"\s*}|
                )
              end
            end

            context 'with suffix regex' do
              let(:params) do
                default_params.merge(
                  filters: [{
                    'type'   => 'allow',
                    'suffix' => '\'/suffix/path/.*\''
                  }]
                )
              end
              it { is_expected.to compile }
              it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|/0 {\s*/type\s*"allow"\s*/suffix\s\'/suffix/path/\.\*\'\s*}|
                )
              end
            end
          end
        end

        context 'grace_period' do
          context 'should not accept 0' do
            let(:params) do
              default_params.merge(grace_period: 0)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should accept positive value' do
            let(:params) do
              default_params.merge(grace_period: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/gracePeriod "1"\s*|
              )
            end
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(grace_period: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'health_check_url' do
          context 'should accept a string' do
            let(:params) do
              default_params.merge(health_check_url: '/health/check/url.html')
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/health_check { /url "/health/check/url.html" }|
              )
            end
          end

          context 'should not accept anything else' do
            let(:params) do
              default_params.merge(health_check_url: ['not', 'a', 'string'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'ignore_parameters' do
          context 'should accept an array of hashes' do
            let(:params) do
              default_params.merge(
                ignore_parameters: [
                  { 'glob' => '*', 'type' => 'deny' },
                  { 'glob' => 'param=*', 'type' => 'allow' }
                ]
              )
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/ignoreUrlParams {\s*/0 { /type "deny" /glob "\*" }\s*/1 { /type "allow" /glob "param=\*" }\s*}|
              )
            end
          end

          context 'require arrays contain a hash' do
            let(:params) do
              default_params.merge(ignore_parameters: ['not a hash', 'another non hash'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should require a value' do
            let(:params) do
              default_params.merge(ignore_parameters: nil)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should respect rank' do
            let(:params) do
              default_params.merge(
                ignore_parameters: [
                  { 'rank' => 1, 'glob' => 'param=*', 'type' => 'allow' },
                  { 'glob' => '*', 'type' => 'deny' }
                ]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/ignoreUrlParams {\s*/0 { /type "deny" /glob "\*" }\s*/1 { /type "allow" /glob "param=\*" }\s*}|
              )
            end
          end
        end

        context 'invalidate' do
          context 'should accept an array of hashes' do
            let(:params) do
              default_params.merge(
                invalidate: [
                  { 'glob' => '*', 'type' => 'deny' },
                  { 'glob' => '*.html', 'type' => 'allow' }
                ]
              )
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/invalidate {\s*/0 { /type "deny" /glob "\*" }\s*/1 { /type "allow" /glob "\*.html" }\s*}|
              )
            end
          end

          context 'require single value be a hash' do
            let(:params) do
              default_params.merge(invalidate: 'not a hash')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'require arrays contain a hash' do
            let(:params) do
              default_params.merge(invalidate: ['not a hash', 'another non hash'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should respect rank' do
            let(:params) do
              default_params.merge(
                invalidate: [
                  { 'rank' => 1000, 'glob' => '*.html', 'type' => 'allow' },
                  { 'glob' => '*', 'type' => 'deny' }
                ]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/invalidate {\s*/0 { /type "deny" /glob "\*" }\s*/1 { /type "allow" /glob "\*.html" }\s*|
              )
            end
          end
        end

       context 'invalidate_handler' do
          context 'should be an absolute path' do
            let(:params) do
              default_params.merge(
                invalidate_handler: 'not/absolute/path'
              )
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
          # context 'should accept relative path' do
          #   let(:params) do
          #     default_params.merge(
          #       invalidate: :undef,
          #       invalidate_handler: '/path/to/script'
          #     )
          #   end
          #   it { is_expected.to compile }
          #   it do
          #     is_expected.to contain_file(
          #       "#{farm_path}/dispatcher.00-#{title}.inc.any"
          #     ).with_content(
          #       %r|/invalidateHandler "/path/to/script"|
          #     ).without_content(
          #       %r|/invalidate |
          #     )
          #   end
          # end
        end

        context 'invalidate and invalidate_handler' do
          context 'should not allow both' do
            let(:params) do
              default_params.merge(
                invalidate: [{ 'glob' => '*.html', 'type' => 'allow' }],
                invalidate_handler: '/path/to/handler'
              )
            end
            it { expect { is_expected.to compile }.to raise_error(/Both.*can not be set./) }
          end
        end

        context 'priority' do
          context 'should accept undef' do
            let(:params) do
              default_params.merge(priority: :undef)
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept 0' do
            let(:params) do
              default_params.merge(priority: 0)
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept 1' do
            let(:params) do
              default_params.merge(priority: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.01-#{title}.inc.any"
              )
            end
          end

          context 'should accept 99' do
            let(:params) do
              default_params.merge(priority: 99)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.99-#{title}.inc.any"
              )
            end
          end

          context 'should not accept 100' do
            let(:params) do
              default_params.merge(priority: 100)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept 101' do
            let(:params) do
              default_params.merge(priority: 101)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept negative priorities' do
            let(:params) do
              default_params.merge(priority: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept strings' do
            let(:params) do
              default_params.merge(priority: '0')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'propagate_synd_post' do
          context 'should accept 0' do
            let(:params) do
              default_params.merge(propagate_synd_post: 0)
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept 1' do
            let(:params) do
              default_params.merge(propagate_synd_post: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/propagateSyndPost "1"\s*|
              )
            end
          end

          context 'should not accept any other positive value' do
            let(:params) do
              default_params.merge(propagate_synd_post: 2)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(propagate_synd_post: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'renders' do
          context 'should accept an array of hashes' do
            let(:params) do
              default_params.merge(
                renders: [
                  { 'hostname' => 'publish.renderer.com', 'port' => '8080' },
                  { 'hostname' => 'another.renderer.com', 'port' => '8080' }
                ]
              )
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'require single value be a hash' do
            let(:params) do
              default_params.merge(renders: 'not a hash')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'require arrays contain a hash' do
            let(:params) do
              default_params.merge(renders: ['not a hash', 'another non hash'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'all params' do
            let(:params) do
              default_params.merge(
                renders: [{
                  'hostname'       => 'publish.hostname.com',
                  'port'           => 8080,
                  'timeout'        => 600,
                  'receiveTimeout' => 300,
                  'ipv4'           => 0
                }]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /renders\s{\s*
                    /renderer0\s{\s*
                      /hostname\s*"publish.hostname.com"\s*
                      /port\s"8080"\s*
                      /timeout\s*"600"\s*
                      /receiveTimeout\s*"300"\s*
                      /ipv4\s"0"\s*
                    }\s*
                  }
                |x
              )
            end
          end

          context 'timeout' do
            let(:params) do
              default_params.merge(
                renders: [{
                  'hostname' => 'publish.hostname.com',
                  'port'     => 8080,
                  'timeout'  => 600
                }]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/renders {\s*/renderer0 {\s*/hostname\s*"publish.hostname.com"\s*/port\s"8080"\s*/timeout\s*"600"\s*}|
              )
            end
          end

          context 'receiveTimeout' do
            let(:params) do
              default_params.merge(
                renders: [{
                  'hostname'       => 'publish.hostname.com',
                  'port'           => 8080,
                  'receiveTimeout' => 600
                }]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /renders\s{\s*
                    /renderer0\s{\s*
                      /hostname\s*"publish.hostname.com"\s*
                      /port\s"8080"\s*
                      /receiveTimeout\s*"600"\s*
                    }\s*
                  }
                |x
              )
            end
          end

          context 'ipv4' do
            let(:params) do
              default_params.merge(
                renders: [{
                  'hostname' => 'publish.hostname.com',
                  'port'     => 8080,
                  'ipv4'     => 0
                }]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/renders {\s*/renderer0 {\s*/hostname\s*"publish.hostname.com"\s*/port\s"8080"\s*/ipv4\s*"0"\s*}|
              )
            end
          end

          context 'multiple renderers' do
            let(:params) do
              default_params.merge(
                renders: [
                  {
                    'hostname' => 'publish.hostname.com',
                    'port'     => 8080,
                    'timeout'  => 600
                  },
                  {
                    'hostname' => 'another.hostname.com',
                    'port'     => 8888,
                    'timeout'  => 100
                  }
                ]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/renderer0 {\s*/hostname\s*"publish.hostname.com"\s*/port\s"8080"\s*/timeout\s*"600"\s*}|
              ).with_content(
                %r|/renderer1 {\s*/hostname\s*"another.hostname.com"\s*/port\s"8888"\s*/timeout\s*"100"\s*}|
              )
            end
          end
        end

        context 'retries' do
          context 'should not accept 0' do
            let(:params) do
              default_params.merge(retries: 0)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should accept positive value' do
            let(:params) do
              default_params.merge(retries: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/numberOfRetries "1"|
              )
            end
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(retries: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'retry_delay' do
          context 'should not accept 0' do
            let(:params) do
              default_params.merge(retry_delay: 0)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should accept positive value' do
            let(:params) do
              default_params.merge(retry_delay: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/retryDelay "1"|
              )
            end
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(retry_delay: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'serve_stale' do
          context 'should accept 0' do
            let(:params) do
              default_params.merge(serve_stale: 0)
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept 1' do
            let(:params) do
              default_params.merge(serve_stale: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/serveStaleOnError "1"\s*|
              )
            end
          end

          context 'should not accept any other positive value' do
            let(:params) do
              default_params.merge(serve_stale: 2)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(serve_stale: -1)
            end
            it {is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'session_management' do
          context 'should accept a hash' do
            let(:params) do
              default_params.merge(session_management: { 'directory' => '/directory/to/cache' })
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'directory only' do
            let(:params) do
              default_params.merge(
                session_management: {
                  'directory' => '/path/to/cache'
                }
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/sessionmanagement {\s*/directory\s*"/path/to/cache"\s*}|
              )
            end
          end

          context 'encode' do
            let(:params) do
              default_params.merge(
                session_management: {
                  'directory' => '/path/to/cache',
                  'encode'    => 'md5'
                }
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/sessionmanagement {\s*/directory\s*"/path/to/cache"\s*/encode\s"md5"\s*}|
              )
            end
          end

          context 'header' do
            let(:params) do
              default_params.merge(
                session_management: {
                  'directory' => '/path/to/cache',
                  'header'    => 'HTTP:authorization'
                }
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/sessionmanagement {\s*/directory\s*"/path/to/cache"\s*/header\s"HTTP:authorization"\s*}|
              )
            end
          end

          context 'timeout' do
            let(:params) do
              default_params.merge(
                session_management: {
                  'directory' => '/path/to/cache',
                  'timeout'   => 1000
                }
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/sessionmanagement {\s*/directory\s*"/path/to/cache"\s*/timeout\s"1000"\s*}|
              )
            end
          end

          context 'all params' do
            let(:params) do
              default_params.merge(
                session_management: {
                  'directory' => '/path/to/cache',
                  'encode'    => 'md5',
                  'header'    => 'HTTP:authorization',
                  'timeout'   => 1000
                }
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /sessionmanagement\s{\s*
                    /directory\s*"/path/to/cache"\s*
                    /encode\s"md5"\s*
                    /header\s"HTTP:authorization"\s*
                    /timeout\s"1000"\s*
                  }
                |x
              )
            end
          end

          context 'should not accept a string' do
            let(:params) do
              default_params.merge(session_management: 'not a hash')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept an array' do
            let(:params) do
              default_params.merge(session_management: ['array', 'of', 'values'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'mutually exclusive with allow authorized' do
            let(:params) do
              default_params.merge(
                session_management: { 'directory' => '/directory/to/cache' },
                allow_authorized: 1
              )
            end
            it { expect { is_expected.to compile }.to raise_error(/mutually exclusive/i) }
          end

          context 'should require directory key' do
            let(:params) do
              default_params.merge(
                session_management: { 'not_directory' => 'a value' }
              )
            end
            it { expect { is_expected.to compile }.to raise_error(/directory is not specified/i) }
          end

          context 'should require directory key to be absolute path' do
            let(:params) do
              default_params.merge(
                session_management: { 'directory' => 'not/absolute/path' }
              )
            end
            it { expect { is_expected.to compile }.to raise_error(/not an absolute path/i) }
          end

          context 'should accept directory with absolute path' do
            let(:params) do
              default_params.merge(
                session_management: { 'directory' => '/an/absolute/path' }
              )
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'encode' do
            context 'should accept md5' do
              let(:params) do
                default_params.merge(
                  session_management: {
                    'directory' => '/path',
                    'encode' => 'md5'
                  }
                )
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should accept hex' do
              let(:params) do
                default_params.merge(
                  session_management: {
                    'directory' => '/path',
                    'encode' => 'hex'
                  }
                )
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any other value' do
              let(:params) do
                default_params.merge(
                  session_management: {
                    'directory' => '/path',
                    'encode' => 'invalid'
                  }
                )
              end
              it { expect { is_expected.to compile }.to raise_error(/not supported for session_management\['encode'\]/) }
            end
          end

          context 'header' do
            context 'should accept a value' do
              let(:params) do
                default_params.merge(
                  session_management: {
                    'directory' => '/path',
                    'header' => 'Any Value is OK'
                  }
                )
              end
              it { is_expected.to compile.with_all_deps }
            end
          end

          context 'timeout' do
            context 'should accept any integer' do
              let(:params) do
                default_params.merge(
                  session_management: {
                    'directory' => '/path',
                    'timeout' => 500
                  }
                )
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any negative value' do
              let(:params) do
                default_params.merge(
                  session_management: {
                    'directory' => '/path',
                    'timeout' => -1
                  }
                )
              end
              it { is_expected.to raise_error(Puppet::ParseError) }
            end

            context 'should not accept anything else' do
              let(:params) do
                default_params.merge(
                  session_management: {
                    'directory' => '/path',
                    'timeout' => 'not an integer'
                  }
                )
              end
              it { expect { is_expected.to compile }.to raise_error(/first argument to be an Integer/) }
            end
          end
        end

        context 'stat_file' do
          context 'should be an absolute path' do
            let(:params) do
              default_params.merge(stat_file: '/path/to/statfile')
            end
            it { is_expected.to compile.with_all_deps }
             it do
                is_expected.to contain_file(
                  "#{farm_path}/dispatcher.00-#{title}.inc.any"
                ).with_content(
                  %r|
                    /statfile\s"/path/to/statfile"
                  |x
                )
              end
          end

          context 'should be not be a relative path' do
            let(:params) do
              default_params.merge(stat_file: 'relative/path')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'stat_files_level' do
          context 'should accept 0' do
            let(:params) do
              default_params.merge(stat_files_level: 0)
            end
            it { is_expected.to compile.with_all_deps }
          end

          context 'should accept positive' do
            let(:params) do
              default_params.merge(stat_files_level: 4)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/statfileslevel "4"|
              )
            end
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(stat_files_level: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'statistics' do
          context 'should accept an array of hashes' do
            let(:params) do
              default_params.merge(
                statistics: [
                  { 'glob' => '*.html', 'category' => 'html' },
                  { 'glob' => '*', 'category' => 'others' }
                ]
              )
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /statistics\s{\s*
                    /categories\s{\s*
                      /html\s{\s/glob\s"\*.html"\s}\s*
                      /others\s{\s/glob\s"\*"\s}\s*
                    }\s*
                  }
                |x
              )
            end
          end

          context 'require single value be a hash' do
            let(:params) do
              default_params.merge(statistics: 'not a hash')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'require arrays contain a hash' do
            let(:params) do
              default_params.merge(statistics: ['not a hash', 'another non hash'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should respect rank' do
            let(:params) do
              default_params.merge(
                statistics: [
                  { 'rank' => 2, 'glob' => '*', 'category' => 'others' },
                  { 'glob' => '*.html', 'category' => 'html' }
                ]
              )
            end
            it { is_expected.to compile }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/statistics {\s*/categories {\s*/html { /glob "\*.html" }\s*/others { /glob "\*" }\s*}\s*}|
              )
            end
          end
        end

        context 'sticky_connections' do
          context 'should accept an array of one values' do
            let(:params) do
              default_params.merge(sticky_connections: ['/content/path'])
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /stickyConnections\s{\s*\s
                    /paths\s{\s*
                      "/content/path"\s*
                    }\s*
                  }
                |x
              )
            end
          end

          context 'should accept an array of many values' do
            let(:params) do
              default_params.merge(sticky_connections: ['/path/to/content', '/another/path/to/content'])
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /stickyConnections\s{\s*\s
                    /paths\s{\s*
                      "/path/to/content"\s*
                      "/another/path/to/content"\s*
                    }\s*
                  }
                |x
              )
            end
          end

          context 'should only be array of strings' do
            let(:params) do
              default_params.merge(sticky_connections: [{ 'not' => 'string' }, { 'another' => 'not string' }])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'unavailable_penalty' do
          context 'should not accept 0' do
            let(:params) do
              default_params.merge(unavailable_penalty: 0)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should accept positive value' do
            let(:params) do
              default_params.merge(unavailable_penalty: 1)
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|/unavailablePenalty "1"|
              )
            end
          end

          context 'should not accept any negative value' do
            let(:params) do
              default_params.merge(unavailable_penalty: -1)
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end
        end

        context 'vanity urls' do
          context 'should accept a hash' do
            let(:params) do
              default_params.merge(vanity_urls: { 'file' => '/path/to/cache', 'delay' => 600 })
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /vanity_urls\s{\s*
                    /url\s"/libs/granite/dispatcher/content/vanityUrls.html"\s*
                    /file\s"/path/to/cache"\s*
                    /delay\s"600"\s*
                  }
                |x
              )
            end
          end

          context 'should not accept a string' do
            let(:params) do
              default_params.merge(vanity_urls: 'not a hash')
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'should not accept an array' do
            let(:params) do
              default_params.merge(vanity_urls: ['array', 'of', 'values'])
            end
            it { is_expected.to raise_error(Puppet::ParseError) }
          end

          context 'file param' do
            context 'should be require' do
              let(:params) do
                default_params.merge(
                  vanity_urls: { 'not_file' => 'a value' }
                )
              end
              it { expect { is_expected.to compile }.to raise_error(/cache file is not specified/i) }
            end

            context 'should be an absolute path' do
              let(:params) do
                default_params.merge(
                  vanity_urls: { 'file' => 'not/absolute/path' }
                )
              end
              it { expect { is_expected.to compile }.to raise_error(/not an absolute path/i) }
            end

            context 'should accept an absolute path' do
              let(:params) do
                default_params.merge(
                  vanity_urls: { 'file' => '/an/absolute/path', 'delay' => 1000 }
                )
              end
              it { is_expected.to compile.with_all_deps }
            end
          end

          context 'delay' do
            context 'should accept any integer' do
              let(:params) do
                default_params.merge(vanity_urls: { 'file' => '/path', 'delay' => 500 })
              end
              it { is_expected.to compile.with_all_deps }
            end

            context 'should not accept any negative value' do
              let(:params) do
                default_params.merge(vanity_urls: { 'file' => '/path', 'delay' => -1 })
              end
              it { expect { is_expected.to compile }.to raise_error(/greater or equal/) }
            end
          end
        end

        context 'virtualhosts' do
          context 'should accept an array of values' do
            let(:params) do
              default_params.merge(virtualhosts: ['www.domainname1.com', 'www.domainname2.com'])
            end
            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_file(
                "#{farm_path}/dispatcher.00-#{title}.inc.any"
              ).with_content(
                %r|
                  /virtualhosts\s{\s*"www.domainname1.com"\s*"www.domainname2.com"\s*}
                |x
              )
            end
          end
        end
      end
    end
  end
end
