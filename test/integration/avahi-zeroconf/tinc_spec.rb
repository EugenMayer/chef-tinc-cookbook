describe package('tinc') do
  it { should be_installed }
end

describe package('avahi-daemon') do
  it { should be_installed }
end

describe package('avahi-autoipd') do
  it { should be_installed }
end

describe file('/etc/tinc/default/tinc.conf') do
  it { should exist }
  its('content') { should match "Port = 655" }
  its('content') { should match "ConnectTo = tincnode1" }
  its('content') { should match "ConnectTo = tincnode2" }
  its('content') { should_not match "ConnectTo = tincnode4" }
  its('content') { should match "Mode = switch" }
  its('content') { should match "Name = tincvpn3" }
end

describe file('/etc/tinc/default/tinc-up') do
  it { should exist }
  its('content') { should match "avahi-autoipd --daemonize --wait [$]INTERFACE" }
  its('content') { should_not match "ifconfig" }
end

describe file('/etc/tinc/default/tinc-down') do
  it { should exist }
  its('content') { should_not match "ifconfig [$]INTERFACE down" }
end

describe file('/etc/tinc/default/rsa_key.priv') do
  it { should exist }
  its('size') { should > 0 }
end

describe file('/etc/tinc/default/rsa_key.pub') do
  it { should exist }
  its('size') { should > 0 }
end

describe file('/etc/tinc/default/hosts/tincnode1') do
  it { should exist }
  its('content') { should match "Address = 15\.0\.0\.1 651" }
  its('content') { should_not match "10\.1\.0\.0/24" }
  its('content') { should_not match "172\.1\.0\.0/16" }
  its('content') { should match "test-pubkey1" }
end

describe file('/etc/tinc/default/hosts/tincnode2') do
  it { should exist }
  its('content') { should match "Address = 15\.0\.0\.2 652" }
  its('content') { should_not match "10\.2\.0\.0/24" }
  its('content') { should_not match "172\.2\.0\.0/16" }
  its('content') { should match "test-pubkey2" }
end

# we excluded that one in our attributes
describe file('/etc/tinc/default/hosts/tincnode4') do
  it { should_not exist }
end

# thats our own host
describe file('/etc/tinc/default/hosts/tincvpn3') do
  it { should exist }
  its('content') { should match "Address = 15\.0\.0\.16 655" }
  its('content') { should_not match "10\.3\.0\.0/24" }
  its('content') { should_not match "172\.3\.0\.0/16" }
  its('content') { should match 'BEGIN RSA PUBLIC KEY'}
  its('content') { should match 'END RSA PUBLIC KEY'}
end
