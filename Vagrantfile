# -*- mode: ruby -*-
# vi: set ft=ruby :

$logger = Log4r::Logger.new('vagrantfile')
def read_ip_address(machine)
  command = "ip -o addr show dev enp0s8 | grep 'inet ' | cut -d: -f2 | awk '{ print $3 }' | cut -f1 -d\"/\""
  result  = ""

  $logger.info "Processing #{ machine.name } ... "

  begin
    # sudo is needed for ifconfig
    machine.communicate.sudo(command) do |type, data|
      result << data if type == :stdout
    end
    $logger.info "Processing #{ machine.name } ... success"
  rescue
    result = "# NOT-UP"
    $logger.info "Processing #{ machine.name } ... not running"
  end

  # the second inet is more accurate
  result.chomp.split("\n").select { |hash| hash != "" }[0]
end

Vagrant.configure("2") do |config|
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true

  if Vagrant.has_plugin?("HostManager")
    config.hostmanager.ip_resolver = proc do |vm, resolving_vm|
      read_ip_address(vm)
    end
  end

  config.vm.define :infra01 do |server|
    server.vm.box = "ubuntu/focal64"
    server.vm.hostname = "infra01"
    server.vm.synced_folder '.', '/vagrant/', disabled: false
    server.vm.network "private_network", type: "dhcp"

    server.hostmanager.aliases = [
      "infra01.example.com",
      "sentry.example.com"
    ]
    server.vm.provider :virtualbox do |vb|
      vb.memory = '8096'
      vb.cpus = '2'
    end

    server.vm.provision "shell", path: "install-docker.sh"
  end
  config.vm.define :infra02 do |server|
    server.vm.box = "ubuntu/focal64"
    server.vm.hostname = "infra02"
    server.vm.synced_folder '.', '/vagrant/', disabled: false
    server.vm.network "private_network", type: "dhcp"

    server.hostmanager.aliases = [
      "infra02.example.com",
    ]
    server.vm.provider :virtualbox do |vb|
      vb.memory = '2096'
      vb.cpus = '1'
    end

    server.vm.provision "shell", path: "install-docker.sh"
  end
end
