# Vision — One Config to Rule Them All

![One Config to Rule Them All](/Images/singleConfig.png)

## The Idea

You define **what you want** your applications/systems/containers/services/servers to look like —
without being vendor-locked into any particular implementation or provider.

*ConfigLMM* materializes this into whichever implementation you feel like using :)

The key insight: most existing declarative tools still ask you *HOW* to accomplish the target state.
*ConfigLMM* only asks you *WHAT* you want. This is called **intention-based configuration**, and it
follows the convention-over-configuration paradigm.

PS. Looks like this matches [RFC 9315 — Intent-Based Networking](https://www.ietf.org/rfc/rfc9315.html),
which you can think of *ConfigLMM* as implementing — and then some.

---

## Target Integrations (Long-term Goal)

The vision is a single config that can target any of these:

**Web / Reverse Proxies**
- [Nginx](https://nginx.org/), [NGINX Unit](https://unit.nginx.org/), [Apache](https://apache.org/)

**Containers / Orchestration**
- [Docker](https://www.docker.com/), [Podman](https://podman.io/), [Kubernetes](https://kubernetes.io/)

**Configuration Management**
- [Ansible](https://www.ansible.com/), [Chef](https://www.chef.io/), [Puppet](https://www.puppet.com/), [Salt](https://saltproject.io/)

**CI/CD / GitOps**
- [Fluxcd](https://fluxcd.io/), [GitLab CI/CD](https://about.gitlab.com/), [Helm](https://helm.sh/), [Spinnaker](https://spinnaker.io/)

**Infrastructure as Code**
- [Terraform](https://www.terraform.io/)

**Cloud Providers**
- [Amazon Web Services (AWS)](https://aws.amazon.com/), [DigitalOcean](https://www.digitalocean.com/),
  [Google Cloud](https://cloud.google.com/), [Microsoft Azure](https://azure.microsoft.com/),
  [Oracle Cloud Infrastructure (OCI)](https://www.oracle.com/cloud/), [OpenStack](https://www.openstack.org/)

**Virtualization**
- [VirtualBox](https://www.virtualbox.org/), [libvirt](https://libvirt.org/), [systemd](https://systemd.io/)

**Testing**
- [Cypress](https://www.cypress.io/), [Puppeteer](https://pptr.dev/), [Selenium](https://www.selenium.dev/),
  [Testsigma](https://testsigma.com/)

**Chaos Engineering**
- [Chaos Monkey](https://github.com/Netflix/chaosmonkey), [Chaos Mesh](https://chaos-mesh.org/)

**Security / Scanning**
- [Greenbone Vulnerability Management (GVM/OpenVAS)](https://community.greenbone.net/),
  [Grype](https://github.com/anchore/grype), [Metasploit](https://www.metasploit.com/)

**Other Environments**
- [Wine](https://www.winehq.org/), [MSYS2](https://www.msys2.org/), [Nix](https://nixos.org/),
  [FreeBSD](https://www.freebsd.org/), [LineageOS](https://lineageos.org/),
  [OpenEmbedded](https://www.openembedded.org/), [Yocto Project](https://www.yoctoproject.org/)

And anything else — any cloud provider, any software (e.g. [KDE](https://kde.org/)), baremetal hosts, VMs, VPS.

The true [GitOps](https://en.wikipedia.org/wiki/DevOps#GitOps) / DevOps / DevSecOps /
[TestOps](https://en.wikipedia.org/wiki/TestOps) / SysOps / [AIOps](https://en.wikipedia.org/wiki/Artificial_Intelligence_for_IT_Operations) /
[DataOps](https://en.wikipedia.org/wiki/DataOps) — or as I call it: **AllTheOps** :)

---

## Benefits

* Compare performance and price among different providers
* Host different services on different providers
* Migrate from local Docker to AWS Lambda and back to on-premises Kubernetes :)
* Move applications across operating systems (e.g. Windows to Linux)
* Easily and quickly switch between different implementations (e.g. Apache → Nginx)
* Try out and compare different software (e.g. reverse proxies, config management tools)
* Provision new baremetal hosts with VMs each hosting Docker containers with multiple services
* Configure different devices (IoT, routers, smartphones) and environments (Wine, MSYS2, WSL, chroot, raw images)
* Reuse configuration among different services
* Automatically follow best practices — secure by default
* Fully test (functionality/integration/end-to-end, load/performance and alerts/monitoring) all infrastructure
* Scan infrastructure for vulnerabilities and insecure configuration
* Practice [chaos engineering](https://en.wikipedia.org/wiki/Chaos_engineering)
* Automatically clean up unused resources
* Anything else you can think of

---

## A Motivating Example

*To illustrate why this matters, consider this scenario:*

* Your brother (a gamer) bought a new laptop with pre-installed Ubuntu
* Your mom bought her first Android smartphone
* Your dad wants to start writing a blog and cares deeply about privacy
* Your friend's IoT company wants to modernize their firmware update infrastructure

Currently, helping all of them would mean:

**For brother:** install Windows, Steam, Fortnite (kernel-level anti-cheat rules out Linux), disable ads/telemetry, configure privacy browser…

**For mom:** pre-install her apps, remove confusing pre-installed apps, adjust settings…

**For dad:**
- Find Big-Tech-free hosting
- Blog software with secure config, user management/authentication
- Automatic backups, monitoring, alerts, intrusion detection

**For friend:** *Uhm...* unless you've spent years working with IoT, it's hard to help much here.

That's *a lot* of work. Now imagine handling it all with one config:

```yaml
BrotherComputer:
    Type: Windows
    Managed: yes
    Apps:
        - Steam
        - Fortnite
        - Roblox
        - Minecraft
        - Firefox

MomPhone:
    Type: Android
    Settings:
        HomeScreen: With App drawer
    Apps:
        - Duolingo
    Remove:
        - CandyCrush

DadBlog:
    # In separate context file, there is specified "Dislikes: Big Tech"
    Type: Blog
    Feature: User Management

Friend:
    # Omitted for brevity but yes ConfigLMM would be able to configure even that
```

**Q: Wait — is this the *whole* config?**
*Yep, exactly like it should be: no more, no less :)*

**Q: Then why have I been writing gazillion bash scripts and thousands of lines of Puppet/Kubernetes/CDK?**
*For years I have been wondering the same.*

**Q: How is this even possible?**
*MAGIC! See the [Implementation section](../CONTRIBUTING.md#implementation) for more details.*

---

## Back to The Reality

Well, unfortunately what I described above is not fully implemented yet.

This is a massive project and it is not realistic that one person can implement it all alone.

This is why *ConfigLMM* is proposed as a **community-driven project** where all of us help each other by implementing parts of it.

When thinking about the combined effort of all contributors, it will save enormous amounts of time for many people — especially as the number of apps/services we want to configure just keeps growing.

Things you want to configure may already be implemented — take a look at [Examples/Implemented.mm.yaml](/Examples/Implemented.mm.yaml) and run `configlmm types` to see what is currently available.

**So please try it out, submit issues and Pull Requests. Help is very much needed and appreciated!**
