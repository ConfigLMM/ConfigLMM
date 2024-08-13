# ConfigLMM - Large Configuration Management Manager

![Yo Dawg I Heard you like config so I put a config in your Config](/Images/configINconfig.png)

## Manage The Management with ease!

You define how you want your applications/systems/containers/services/servers
to work without being vendor locked into any particular implementation or provider.

*ConfigLMM* will materialize this into whichever implementation you feel like using that day :)

**One Config to Rule Them All**:

* [Nginx](https://nginx.org/)
* [NGINX Unit](https://unit.nginx.org/)
* [Apache](https://apache.org/)
* [Docker](https://www.docker.com/)
* [Podman](https://podman.io/)
* [Kubernetes](https://kubernetes.io/)
* [Ansible](https://www.ansible.com/)
* [Chef](https://www.chef.io/)
* [Fluxcd](https://fluxcd.io/)
* [GitLab CI/CD](https://helm.sh/)
* [Helm](https://helm.sh/)
* [Puppet](https://www.puppet.com/)
* [Salt](https://saltproject.io/)
* [Spinnaker](https://spinnaker.io/)
* [Terraform](https://www.terraform.io/)
* [Amazon Web Services (AWS)](https://aws.amazon.com/)
* [DigitalOcean](https://www.digitalocean.com/)
* [Google Cloud](https://cloud.google.com/)
* [Microsoft Azure](https://azure.microsoft.com/)
* [Oracle Cloud Infrastructure (OCI)](https://www.oracle.com/cloud/)
* [OpenStack](https://www.openstack.org/)
* [VirtualBox](https://www.virtualbox.org/)
* [Chaos Monkey](https://github.com/Netflix/chaosmonkey)
* [Chaos Mesh](https://chaos-mesh.org/)
* [Cypress](https://www.cypress.io/)
* [Puppeteer](https://pptr.dev/)
* [Testsigma](https://testsigma.com/)
* [Selenium](https://www.selenium.dev/)
* [Greenbone Vulnerability Management (GVM/OpenVAS)](https://community.greenbone.net/)
* [Grype](https://github.com/anchore/grype)
* [Metasploit](https://www.metasploit.com/)
* [OpenCost](https://www.opencost.io/)
* [MSYS2](https://www.msys2.org/)
* [libvirt](https://libvirt.org/)
* [systemd](https://systemd.io/)
* [Wine](https://www.winehq.org/)
* [OpenEmbedded](https://www.openembedded.org/)
* [Yocto Project](https://www.yoctoproject.org/)
* [Nix](https://nixos.org/)
* [FreeBSD](https://www.freebsd.org/)
* [LineageOS](https://lineageos.org/)
* Any Cloud Provider
* Any kind of software (eg. [KDE](https://kde.org/), )
* Baremetal - your own host/VMs/VPS
* And everything else

The true [GitOps](https://en.wikipedia.org/wiki/DevOps#GitOps)/DevOps/DevSecOps/[TestOps](https://en.wikipedia.org/wiki/TestOps)/SysOps/[AIOps](https://en.wikipedia.org/wiki/Artificial_Intelligence_for_IT_Operations)[DataOps](https://en.wikipedia.org/wiki/DataOps) which I call AllTheOps :)

![One Config to Rule Them All](/Images/singleConfig.png)

## Benefits

* Compare performance and price among different providers
* Host different services on different providers
* Migrate from local Docker to AWS Lambda and back to on-premises Kubernetes :)
* Move your applications across operating systems (eg. Windows to Linux etc)
* Easily and quickly switch between different implementations like from Apache to Nginx and so on
* Try out and compare different software easily (eg. reverse proxies, configuration management software etc)
* Provision new baremetal host with several VMs where each host bunch of Docker containers with multiple services inside
* Configure different devices (eg. IoT, routers, smartphones, coffee machines, fridges) and environments (eg. Wine, MSYS2, WSL, chroot, raw images) and a lot of other things
* Reuse configuration among different services
* Automatically follow best practises and secure by default without having to know anything about that
* Fully test (functionality/integration/end-to-end, load/performance and alerts/monitoring) all deployed infrastructure and applications
* Scan all your infrastructure for vulnerabilities and insecure configuration
* Practise [chaos engineering](https://en.wikipedia.org/wiki/Chaos_engineering) by testing how well systems handle various faults (eg. you have RAID1 does dropping a disk really doesn't affect applications? or terminating one application instance or database or even whole region)
* Automatically cleanup unused resources and other unneeded things
* Don't be limited with what your Platform Provider tools (CLIs/SDKs/APIs) support (eg. configure things thru Web UI portal if there's no other option)
* Anything else you can think of

Are you wondering if so many features won't make this unbearably complicated and unmaintainable?

I don't think so and this project will try to show that :) In fact I think most of existing
tools are overly complex. Think about Helm Charts/CloudFormation/Kubernetes/Puppet and such.

While most tools use declarative configuration I think they still got it wrong
because they are too low level by asking you to define *HOW* to accomplish target state while I think
configuration should just describe what you *WANT* the target state to be :)

So with *ConfigLMM* you only define what you *WANT* but don't describe *HOW* to accomplish that.

Some examples with idea of defining "*WHAT I WANT*":

* I need "*THESE*" files to be at "*MYDOMAIN*" (I don't even care where it runs just make it happen)
* "*THIS*" software hosted on "*MY*" VPS using "nginx" and "Puma" (yes I do have some preferences)
* run "*THIS*" container on "*FRIENDS*" Google Cloud account in "*THOSE*" regions
* I need "*THESE*" fonts on "*ALL*" my machines

I call this intention based configuration which is used by *ConfigLMM* and it also follows convention over configuration paradigm.

PS. Looks like I'm not only one thinking this way, see [RFC 9315 - Intent-Based Networking](https://www.ietf.org/rfc/rfc9315.html).
So essentially you can think of *ConfigLMM* as loose implementation of that RFC but even more because not only Networking part.

### Still not sold?

Then consider this scenario:

* Your brother who is a gamer bought new laptop which came with pre-installed Ubuntu
* Your mom bought Android smartphone which is her first one ever
* Your dad wants to start writing a blog and he cares deeply about his data and privacy
* Your friend who works at IoT company is looking into how to optimize company's infrastructure/software stack

So currently how would you make life easier/better for your family and friends(s)?

* Let them struggle on their own?
* Install and configure everything yourself? If so are you following best practices, with security and backups in mind? How sad your dad would be if blog stopped working? How much of your time this would take?

Let's have a meeting and find out what they actually want to do with their devices.

* Brother: I want to play Fortnite.
* Mom: Oh I don't know anything about this.
* Dad: I want to share some private articles with few friends but I don't want to give my data to [Big Tech](https://en.wikipedia.org/wiki/Big_Tech)!
* Friend: So my company has thousands of IoT devices that need firmware updates and we want to modernize/optimize our homegrown solution/control plane that has grown over many years to unimaginable complexity and has become quite fragile and thus making any changes is very risky/hard/slow.

Okay so now that we have an idea what we need we can start making it happen.
But do you know all the things that are needed to accomplish these goals? Your friend???

For brother:

* Fortnite - uses [kernel-level anti-cheat](https://lutris.net/games/fortnite/) so this rules out all non-Windows OS'es
* Need to install Windows, [Steam](https://store.steampowered.com/about/), Fortnite and his other favorite games
* You might not want ads/telemetry enabled on his Windows so need to disable those aswell
* Probably best to use privacy respecting browser
* Configure and install bunch of other things

For mom:

* You know she'll struggle with finding and installing her favorite apps so you want to preinstall those
* You might want to remove/uninstall some of already preinstalled apps because they might confuse her
* There are some settings that are not good preference for her so you want to change those aswell

For dad:

* Need some place to host blog that is not Big Tech
* Need authentication (maybe with user management?) so that he can share his private articles to friends
* For blog:

  * Secure configuration and keeping up with new vulnerabilities (very common for blog software)
  * Automatic backups
  * Monitoring/Alerts
  * Intrusion detection? What if someone gains access and posts bunch of spam there?

For friend:

*Uhm...* Yeah unless you've spent years working with IoT it's unlikely that you can help him there much.

I don't know about you but for me this all looks like *A LOT* of work.

So let's just move to the future and use *ConfigLMM* to solve all these problems :)

By using *ConfigLMM* you can create a configuration (even work together on it with family) that will satisfy everyone's needs and then make it all happen like *MAGIC* (just what they think it is)

So let's take a look at it:

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

Q: Wait what, is this all, *the WHOLE* config? *Yep, exactly like it should be, no more, no less :)*

Q: Then *WHY* have I been writing gazillion of bash scripts and thousands of Puppet/Kubernetes/[CDK](https://aws.amazon.com/cdk/) code lines? *For years I have been wondering the same*

Q: But what about friend how will I know how to write such config? You don't need to know how but just tell him to use *ConfigLMM* and his company's development team will spend some time creating it.

Q: How is this even possible? *MAGIC! See Implementation section for more details but generally you don't even need to care how*

## Back to The Reality

Well unfortunately what I just described is not really implemented yet.

This is a massive project and no matter how much I want to build it - it's not realistic that I can implement it all on my own.

And this is why I'm proposing this to be a community driven project where all of us help each other by implementing some parts of it.

When thinking about all of us together then it will save a lot of time for many of us. Especially as new Apps we want to host and configure just keeps growing.

Also maybe things you want to configure are already implemented so take a look at [Examples/Implemented.mm.yaml](/Examples/Implemented.mm.yaml) and see what we already have! :)

So I ask you to try it out (you can run `confilmm types` to see what is implemented), submit your issues and Pull Requests. I definitely need your and everyone's help to achieve this project's goal.

## Installation

First you need to have Ruby and RubyGems. Then you can install it with:

    $ gem install ConfigLMM

If that doesn't work (eg. your Ruby is too old) then install with (it will install [RVM](https://rvm.io/))

```
$ curl -sS https://raw.githubusercontent.com/ConfigLMM/ConfigLMM/master/bootstrap.sh | sh
```

## Usage

Create yaml file with desired config, eg.
```yaml
Wiki:
    Type: Gollum
    Domain: wiki.example.to
    CertName: Gollum
    Resources:
        NS:
            Type: TonicDNS
            Domain: example.to
            Nameservers:
                ns.example.to: 192.168.5.5
        DNS:
            Type: PowerDNS
            DNS:
                example.to:
                    wiki: CNAME=@ # `@` means point it to the domain root
                    '@': A=@me # first `@` means domain root and `@me` means current external IP
```

Then deploy it and let the magic happen!
```
$ configlmm help
Commands:
  configlmm build [CONFIGS...]     # Build configuration in deployable form
  configlmm deploy [CONFIGS...]    # Deploy configuration
  configlmm diff [CONFIGS...]      # Show changes that will be applied with next deploy
  configlmm help [COMMAND]         # Describe available commands or one specific command
  configlmm list [CONFIGS...]      # List things
  configlmm refresh [CONFIGS...]   # Update local state to match deployed things
  configlmm validate [CONFIGS...]  # Check whether the configuration is valid
  configlmm version                # Show program's version

Options:
      [--level=LEVEL]                    # Logging level to use
                                         # Default: info
                                         # Possible values: debug, info, warn, error
  -n, [--dry], [--no-dry], [--skip-dry]  # Only show actions without performing

$ configlmm deploy config.mm.yaml
Deploying...
Deploying NS: TonicDNS
Tonic - Successful DNS Change
Deploying DNS: PowerDNS
Deploying Wiki: Gollum
Deploy successful!
```

## FAQ

**Q: Why name it "*Large*"? Why "*L*" is after Config in *ConfigLMM*?**

To be a pun of [LLM](https://en.wikipedia.org/wiki/Large_language_model) and like with a language model you don't need to write down every single detail. Also *ConfigLMM* is definitely smarter than LLMs :)

Another thing is that it really is quite *Large*/big project to accomplish this goal with so many features.

**Q: I already have infrastructure deployer/orchestrator that I love and don't want to change so this is useless for me?**

Not necessarily, for example you can use `configlmm build` feature to create configs and then use your own orchestrator to do actual provisioning/deployment (and even do additional customization on built configs).

**Q: Aren't this many features a bit too much?**

No :)

**Q: Is this actually doable?**

Yes :)

**Q: Are you crazy/insane?**

Yes :) But maybe everyone/whole world is by learning hundreds of different tools with different versions each with dozens of incompatible/conflicting options/flags and some with couple of configuration files aswell.

I think the complexity of that is insane and the amount of different tools only keeps growing.

Can you count how many different tools/programs have you used today/this week/month? What about in a year or in your whole life together?


## Implementation

To accomplish this functionality *ConfigLMM* consists of 3 main parts:

1. High level configuration file format (superset/abstraction) that describes your infrastructure intentions
2. Core Framework that holds *ConfigLMM* together
2. Plugins for different apps/services/systems which implement build/deploy logic using provided configuration

Note that this project is in very early development stage and so there won't really be API/spec stability for some while.
You might need to update your configuration as new versions are released and design iterated and improved with time.
Unfortunately that's the sad reality we live in and things can't always be perfect from the start :)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ConfigLMM/ConfigLMM.
Pretty Please! :)

### Implement a new Plugin

To implement a new Plugin, simply create a file with name `$pluginName.lmm.rb` and put it in respective category in `Plugins` folder.

Then in that file create a method with name `action#{pluginName}Deploy` and implement logic there. It will be loaded automatically so you don't need any other changes.

I highly recommend looking at existing plugins. Also you can copy and rename `porkbun.lmm.rb` to use as a base.

### Model Configuration for App/Service/System

Try to model your existing infrastructure with high level YAML and submit those under Examples folder.

This will allow us to come up with best design for configuration file format even before we start implementing such configuration.

And you never know, maybe someone will love it so much he'll implement necessary Plugins so then others and you will be able to use *configlmm* to deploy such infrastructure.

