# frozen_string_literal: true

describe file('/etc/tinc/default/tinc-up') do
  it { should exist }
  its('content') { should match /ifconfig \$INTERFACE 10\.0\.0\.\d+ netmask 255\.255\.255\.0/ }
end

describe file('/etc/tinc/default/hosts/tincvpn3') do
  it { should exist }
  its('content') { should match /Address = 10\.0\.2\.15 655/ }
  its('content') { should match /Subnet = 10\.0\.0\.\d+\/32/ }
end
