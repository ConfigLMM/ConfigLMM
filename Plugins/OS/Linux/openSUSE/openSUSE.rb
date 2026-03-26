
module ConfigLMM
    module LMM
        module OS
            module OpenSUSE

                def buildAutoYaSTConfig(config, osInfo, id, target, options)
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/openSUSE/autoinst.xml.erb'))
                    config['Patterns'] ||= []
                    if osInfo['Id'] == SUSE_MICROOS_ID
                        config['Patterns'] << 'microos_base'
                        config['Patterns'] << 'microos_base_zypper'
                    end
                    renderTemplate(template, config, outputFolder + 'autoinst.xml', options)
                end

                def buildISOAutoYaST(id, iso, target, options)
                    outputFolder = options['output'] + '/iso/'
                    mkdir(outputFolder, false)
                    extractISO(iso, outputFolder, options)
                    FileUtils.chmod_R(0750, outputFolder) # Need to make it writeable so it can be deleted
                    copy(options['output'] + '/' + id + '/autoinst.xml', outputFolder, false)

                    opts = []
                    if target['DefaultNetwork']['IP'] != 'dhcp'
                        ifcfg = "ifcfg=\"e*=#{target['DefaultNetwork']['IP']}"
                        if target['DefaultNetwork']['Gateway'] || target['DefaultNetwork']['DNS']
                            ifcfg +=  ',' + target['DefaultNetwork']['Gateway'].to_s
                            if target['DefaultNetwork']['DNS']
                                ifcfg +=  ',' + target['DefaultNetwork']['DNS']
                                ifcfg +=  ',' + Addressable::IDNA.to_ascii(target['Domain']) if target['Domain']
                            end
                        end
                        ifcfg += '"'
                        opts << ifcfg
                    end

                    opts << 'autoyast=device://sr0/autoinst.xml'

                    cfg = outputFolder + "boot/x86_64/loader/isolinux.cfg"
                    local.fileReplace(cfg, 'default harddisk', 'default linux', options)
                    local.fileReplace(cfg, 'append initrd=initrd splash=silent showopts', 'append initrd=initrd splash=silent ' + opts.join(' '), options)
                    local.fileReplace(cfg, 'prompt		1', 'prompt		0|', options)
                    local.fileReplace(cfg, 'timeout		600', 'timeout		1|', options)

                    cfg = outputFolder + "EFI/BOOT/grub.cfg"
                    local.fileReplace(cfg, /timeout=.*/, 'timeout=1', options)
                    local.fileReplace(cfg, 'linux splash=silent', 'linux splash=silent ' + opts.join(' '), options)

                    patchedIso = File.dirname(iso) + '/patched.iso'
                    rebuildISO(iso, outputFolder, patchedIso, options)
                    patchedIso
                end

                def agamaBootOptions(target)
                    opts = []

                    if !target['Users'].to_h['root'].to_h.empty?
                        if target['Users']['root']['PasswordHash']
                            opts << "live.password_hash='#{target['Users']['root']['PasswordHash']}'"
                        elsif target['Users']['root']['Password']
                            opts << "live.password='#{target['Users']['root']['Password']}'"
                        end
                    end

                    opts << LinuxNetwork::kernelNetworkCMD(target)
                    opts << 'inst.listen_on=localhost'
                    opts
                end

                def updateGrub2Config(outputFolder, opts, options)
                    cfg = outputFolder + 'boot/grub2/grub.cfg'
                    local.fileReplace(cfg, 'default=0', 'default=1', options)
                    local.fileReplace(cfg, /timeout=.*/, 'timeout=1', options)

                    local.fileReplace(cfg, '${isoboot}', "${isoboot} #{opts.join(' ')}", options)
                end

                def buildISOAgama(osInfo, id, iso, target, options)
                    patchedIso = nil

                    outputFolder = options['output'] + '/iso/'
                    local.mkdir(outputFolder, false)

                    extractISO(iso, outputFolder, options)
                    FileUtils.chmod_R(0750, outputFolder)

                    autoinst = OpenSUSE::buildAgamaAutoInst(osInfo['ProductId'], target)
                    local.fileWrite(outputFolder + 'autoinst.json', JSON.pretty_generate(autoinst), options['dry'])

                    opts = agamaBootOptions(target)
                    opts << 'inst.auto=device://sr0/autoinst.json'
                    updateGrub2Config(outputFolder, opts, options)

                    patchedIso = File.dirname(iso) + '/patched.iso'
                    rebuildISO(iso, outputFolder, patchedIso, options)
                    patchedIso
                end

                def preparePXEAgama(ourPath, iso, outputFolder, osInfo, id, target, options)
                    extractISO(iso, outputFolder, options)
                    FileUtils.chmod_R(0750, outputFolder)

                    autoinst = OpenSUSE::buildAgamaAutoInst(osInfo['ProductId'], target)
                    local.fileWrite(outputFolder + 'autoinst.json', JSON.pretty_generate(autoinst), options['dry'])

                    opts = agamaBootOptions(target)
                    raise 'Missing URL to PXE server' unless ourPath

                    opts << "inst.auto=#{ourPath}/autoinst.json"
                    opts << "root=live:#{ourPath}/LiveOS/squashfs.img"

                    updateGrub2Config(outputFolder, opts, options)
                    local.copy(outputFolder + 'boot/grub2/grub.cfg', outputFolder + 'EFI/BOOT/grub.cfg', options['dry'])
                    local.mkdir(outputFolder + '.snapshots', options['dry'])
                    local.fileWrite(outputFolder + '.snapshots/grub-snapshot.cfg', '', options['dry'])

                    biosBootFile = '/boot/x86_64/loader/eltorito.img'
                    uefiBootFile = 'EFI/BOOT/grub.efi'

                    [biosBootFile, uefiBootFile]
                end

                def self.buildAgamaAutoInst(productId, target)
                    autoinst = {
                        product: {
                                  id: productId
                                 },
                        localization: {
                                       language: 'en_US.UTF-8',
                                       keyboard: 'us',
                                       timezone: 'UTC'
                                      }
                    }

                    if target['Domain']
                        autoinst['hostname'] = {}
                        autoinst['hostname']['static'] = Addressable::IDNA.to_ascii(target['Domain'])
                    end

                    if !target['Network'].to_h['Interfaces'].to_h.empty?
                        autoinst['network'] = {}
                        target['Network'].to_h['Interfaces'].each do |interface, config|
                            self.buildAgamaNetworkConnections(name, config)
                            autoinst['network']['connections'] << network
                        end
                        autoinst['network']['connections'] = [network]
                    elsif !target['DefaultNetwork'].to_h.empty?
                        autoinst['network'] = {}
                        autoinst['network']['connections'] = [self.buildAgamaNetworkConnections('Ethernet', target['DefaultNetwork'])]
                    end

                    target['Users'].to_h.each do |user, info|
                        data = {}
                        if info['PasswordHash']
                            data['hashedPassword'] = true
                            data['password'] = info['PasswordHash']
                        else
                            data['hashedPassword'] = false
                            data['password'] = info['Password']
                        end
                        data['sshPublicKey'] = info['AuthorizedKeys'].join("\n") if info.key?('AuthorizedKeys')

                        if user == 'root'
                            autoinst['root'] = data
                        elsif !autoinst.key?('user')
                            data['userName'] = user
                            autoinst['user'] = data
                        end
                    end

                    if !target['Apps'].to_a.empty?
                        autoinst['software'] = {}
                        autoinst['software']['packages'] = []
                        target['Apps'].each do |app|
                            autoinst['software']['packages'] << app.downcase
                        end
                    end

                    autoinst['bootloader'] = {}
                    autoinst['bootloader']['timeout'] = 3

                    if !target['Services'].to_a.empty?
                        servicesScript = {
                            'name': 'services',
                            'chroot': true
                        }
                        servicesScript['content'] = "#!/usr/bin/sh\n"
                        servicesScript['content'] += target['Services'].map { |service| "systemctl enable #{service}" }.join("\n") + "\n"

                        autoinst['scripts'] = {}
                        autoinst['scripts']['post'] = [servicesScript]
                    end

                    autoinst
                end

                def self.buildAgamaNetworkConnections(name, config)
                    network = {
                        id: name,
                        persistent: true
                    }
                    if config.is_a?(Hash)
                        if config['IP']
                            if IPAddr.new(config['IP']).ipv6?
                                network['method4'] = 'auto'
                                network['method6'] = 'manual'
                            else
                                network['method4'] = 'manual'
                                network['method6'] = 'auto'
                            end
                            network['addresses'] = [config['IP']]
                        end

                        if config['Gateway']
                            if IPAddr.new(config['Gateway']).ipv6?
                                network['gateway6'] = config['Gateway']
                            else
                                network['gateway4'] = config['Gateway']
                            end
                        end

                        if config['DNS']
                            dns = config['DNS']
                            dns = [dns] unless dns.is_a?(Array)
                            network['nameservers'] = dns
                        end
                    else
                        if config == 'dhcp'
                            network['method4'] = 'auto'
                            network['method6'] = 'auto'
                        else
                            if IPAddr.new(config).ipv6?
                                network['method4'] = 'auto'
                                network['method6'] = 'manual'
                            else
                                network['method4'] = 'manual'
                                network['method6'] = 'auto'
                            end
                            network['addresses'] = [config]
                        end
                    end
                    network
                end

            end
        end
    end
end
