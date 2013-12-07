class ::Chef::Recipe
  include ::Opscode::ChefClient::Helpers
end

# libraries/helpers.rb method to DRY directory creation resources
client_bin = find_chef_client
log "Found chef-client in #{client_bin}"
node.default["chef_client"]["bin"] = client_bin
create_directories

dist_dir, conf_dir = value_for_platform_family(
  ["debian"] => ["debian", "default"],
  ["fedora"] => ["redhat", "sysconfig"],
  ["rhel"] => ["redhat", "sysconfig"],
  ["suse"] => ["suse", "sysconfig"]
)

ruby_block "restart_warning" do
  block do
    Chef::Log.warn("CHEF CONFIG CHANGED!  PLEASE RESTART chef-client!!!")
  end
  action :nothing
end

notifier "Chef Restart Required" do
  to "eric.herot@evertrue.com"
  message "One or more chef configurations has been updated on this node.  A manual chef-client restart will be required to make this configuration live."
  action :nothing
end

template "/etc/init.d/chef-client" do
  source "#{dist_dir}/init.d/chef-client.erb"
  mode 0755
  variables :client_bin => client_bin
  notifies :send, "notifier[Chef Restart Required]"
  notifies :create, "ruby_block[restart_warning]"
end

template "/etc/#{conf_dir}/chef-client" do
  source "#{dist_dir}/#{conf_dir}/chef-client.erb"
  mode 0644
  notifies :send, "notifier[Chef Restart Required]"
  notifies :create, "ruby_block[restart_warning]"
end

service "chef-client" do
  supports :status => true
  action [:enable, :start]
end
