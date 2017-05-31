describe file('/etc/tinc/default/tinc.conf') do
  it { should exist }
  its('content') { should match "Mode = switch" }
end