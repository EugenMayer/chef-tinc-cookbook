# frozen_string_literal: true

describe package('tinc') do
  it { should be_installed }
end

describe file('/etc/tinc/nets.boot') do
  its('content') { should_not match 'default' }
  its('content') { should match 'infravpn' }
end

describe file('/etc/tinc/default/tinc.conf') do
  it { should_not exist }
end

describe file('/etc/tinc/infravpn/tinc.conf') do
  it { should exist }
end

describe file('/etc/tinc/default/tinc-up') do
  it { should_not exist }
end

describe file('/etc/tinc/infravpn/tinc-up') do
  it { should exist }
  its('content') { should match %r{10.0.0.\d+ netmask 255.255.255.0} }
end

describe file('/etc/tinc/default/tinc-down') do
  it { should_not exist }
end

describe file('/etc/tinc/infravpn/tinc-down') do
  it { should exist }
end

describe file('/etc/tinc/default/rsa_key.priv') do
  it { should_not exist }
end

describe file('/etc/tinc/infravpn/rsa_key.priv') do
  it { should exist }
end

describe file('/etc/tinc/default/rsa_key.pub') do
  it { should_not exist }
end

describe file('/etc/tinc/infravpn/rsa_key.pub') do
  it { should exist }
end

describe file('/etc/tinc/default/hosts') do
  it { should_not exist }
end

describe file('/etc/tinc/infravpn/hosts/infranode1') do
  it { should exist }
end

# we excluded that one in our attributes
describe file('/etc/tinc/default/hosts/tincnode4') do
  it { should_not exist }
end

describe file('/etc/tinc/infravpn/hosts/tincnode4') do
  it { should_not exist }
end

# thats our own host
describe file('/etc/tinc/default/hosts/tincvpn3') do
  it { should_not exist }
end

describe file('/etc/tinc/infravpn/hosts/tincvpn3') do
  it { should exist }
end
