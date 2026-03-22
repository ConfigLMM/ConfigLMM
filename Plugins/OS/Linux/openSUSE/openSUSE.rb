
module ConfigLMM
    module LMM
        module OS
            module OpenSUSE

                def buildISOAutoYaST(id, iso, target, options)
                    outputFolder = options['output'] + '/iso/'
                    mkdir(outputFolder, false)
                    local.exec("xorriso -osirrox on -indev #{iso} -extract / #{outputFolder}")
                    FileUtils.chmod_R(0750, outputFolder) # Need to make it writeable so it can be deleted
                    copy(options['output'] + '/' + id + '/autoinst.xml', outputFolder, false)

                    cfg = outputFolder + "boot/x86_64/loader/isolinux.cfg"
                    local.exec("sed -i 's|default harddisk|default linux|' #{cfg}")
                    local.exec("sed -i 's|append initrd=initrd splash=silent showopts|append initrd=initrd splash=silent autoyast=device://sr0/autoinst.xml|' #{cfg}")
                    local.exec("sed -i 's|prompt		1|prompt		0|' #{cfg}")
                    local.exec("sed -i 's|timeout		600|timeout		1|' #{cfg}")

                    ifcfg = ''
                    if target['DefaultNetwork']['IP'] != 'dhcp'
                        ifcfg = "ifcfg=\"eth*=#{target['DefaultNetwork']['IP']}"
                        if target['DefaultNetwork']['Gateway'] || target['DefaultNetwork']['DNS']
                            ifcfg +=  ',' + target['DefaultNetwork']['Gateway'].to_s
                            if target['DefaultNetwork']['DNS']
                                ifcfg +=  ',' + target['DefaultNetwork']['DNS']
                                ifcfg +=  ',' + Addressable::IDNA.to_ascii(target['Domain']) if target['Domain']
                            end
                        end
                        ifcfg += '"'
                    end

                    cfg = outputFolder + "EFI/BOOT/grub.cfg"
                    local.exec("sed -i 's|timeout=.*|timeout=1|' #{cfg}")
                    local.exec("sed -i 's|linux splash=silent|linux splash=silent #{ifcfg} autoyast=device://sr0/autoinst.xml|' #{cfg}")

                    patchedIso = File.dirname(iso) + '/patched.iso'
                    local.exec("xorriso -as mkisofs -no-emul-boot -boot-info-table -boot-load-size 4 -iso-level 4 -b boot/x86_64/loader/isolinux.bin -c boot/x86_64/loader/boot.cat -eltorito-alt-boot -no-emul-boot -e boot/x86_64/efi -o #{patchedIso} #{outputFolder}")
                    patchedIso
                end

            end
        end
    end
end
