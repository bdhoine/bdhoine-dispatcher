require 'spec_helper'

describe 'render_farm_filter' do
  # it { is_expected.to run.with_params.and_raise_error(Puppet::ParseError, 'render_farm_filter() wrong number of arguments (0; must be 1)') }
  # it { is_expected.to run.with_params('1', '2').and_raise_error(Puppet::ParseError, 'render_farm_filter() wrong number of arguments (0; must be 1)') }
  # it { is_expected.to run.with_params(1).and_raise_error(Puppet::ParseError, 'render_farm_filter() argument should be an string.') }
  # it { is_expected.to run.with_params({'test'}).and_raise_error(Puppet::ParseError, 'render_farm_filter() argument should be an string.') }
  it { is_expected.to run.with_params('*').and_return('"*"') }
  it { is_expected.to run.with_params('\'.*\'').and_return('\'.*\'') }
end