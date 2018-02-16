package %w(avahi-daemon avahi-utils avahi-autoipd)

service 'avahi-daemon' do
  action [ :enable, :start ]
end
