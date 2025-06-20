---
title: Hardware Requirements
description: Describes the hardware requirements for running and administering an Ethereum node as described in the guides.
sidebar:
  order: 1
---
## Node Server
- headless, always-online computer, running Ubuntu Server and the Ethereum node software
- Mini PC form factor is ideal for its power efficiency
- NVMe primary disk is required for its high I/O speed
	- see Yorick Downe's [Great and less great SSDs for Ethereum nodes](https://gist.github.com/yorickdowne/f3a3e79a573bf35767cd002cc977b038)
- cheaper/slower 2.5" HDD or SSD as a secondary drive is sufficient for less-demanding "ancient" blockchain data
- for example:
	- [Intel NUC 10 Performance Kit – Intel Core i7 Processor (Tall Chassis)](https://www.amazon.com/gp/product/B08357VWB2/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&psc=1)
		- only drawback of this chassis is that, despite being the "tall" model, it will not fit a 15mm 2.5" 5TB HDD, so you're stuck with purchasing an expensive SSD despite not needing SSD speeds, such as the 4TB linked below
	- [32 GB (2 x 16 GB) DDR4 2666 RAM](https://www.amazon.com/CORSAIR-Vengeance-Performance-260-Pin-CMSX32GX4M2A2666C18/dp/B01BGZEVHU)
	- [Western Digital SN750 2TB](https://www.amazon.com/Black-SN750-NVMe-Internal-Gaming/dp/B07M9VXSXG)
	- [SAMSUNG 870 EVO 4TB 2.5 Inch SATA III Internal SSD](https://www.amazon.com/gp/product/B08QBL36GF/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&th=1)
		- 2.5" SSDs > 4TB are astronomically more expensive, but 4TB as secondary is plenty for the foreseeable future.  Worst-case scenario: switching to external USB secondary storage in a few years (inelegant, but the I/O reqs are low enough where this would work)
	- keyboard, mouse, monitor
		- these will only be needed during the initial setup

## Client PC
- your laptop or desktop computer, connected to the same LAN as the node server
- will be used to administer the node server via SSH, secured by key+passphrase authentication
- this guide presupposes that you have [Mint](https://linuxmint.com/) installed.  With minor modifications, you could use another Linux distro, Windows 10+ via WSL (Windows Subsystem for Linux), or Mac OS, but that is beyond the scope of this guide

## Air-Gapped PC
- will be used to generate seed phrases, and to sign transactions by typing in seed phrases
- any old, retired PC will do so long as it can run Linux Mint
- once commissioned, must *NEVER* be connected to the internet or any networked device
- should not have a storage disk installed; a live Linux USB flash drive will be used to boot into RAM
- should not have wireless capabilities (e.g. WiFi/4G/5G), or should at least have these functions disabled in the BIOS or by physical toggle/removal if available

## Router / Firewall
- the hub of your LAN which connects the node server & client PC together and to the internet
- must have decent CPU and RAM, able to run [OpenWRT](https://openwrt.org/) and handle the node server's high traffic
- for example:
	- [Linksys WRT3200ACM](https://www.amazon.com/dp/B01JOXW3YE?&tag=router10-20) (*Èl Classicò Americàno*)
		- long in the tooth, but still works well.  It has dual-partition storage to house two firmware installs simultaneously and switches between them automatically during flashing, which makes tinkering safer.  It's also widely supported with a huge userbase, so finding help on the various forums is easy
	- a more powerful (and expensive) alternative would be an official [pfSense](https://www.pfsense.org/) or [OPNSense](https://opnsense.org/) appliance, and running its respective operating system for routing & firewall duties instead of OpenWRT, but that is beyond the scope of this guide
	- there are newer WiFi 6+ routers which are open source-friendly, including a variety of cheap Chinesium appliances which are popular in the "tech bro" community, but they have spotty hardware support, suffer occasional zero-day exploits ([exhibit A](https://news.ycombinator.com/item?id=41605680)), supply-chain attacks ([exhibit B](https://archive.is/xewlX)), and backdoors ([exhibit C](https://wyzguyscybersecurity.com/chinese-arm-processors-backdoor/)), but that is beyond the scope of this guide
	- I recommend sticking with *Èl Classicò Americàno* for now.  If better WiFi is needed, disable its WiFi radios and connect a separate AP

## UPS Battery Backup
- provides surge & sag protection, extending the life of the node server and router
- keeps the node server and router running during brief power outtages
- gracefully shuts-down the node server during extended power outtages
- for example:
	- [CyberPower CP1500PFCLCD](https://www.amazon.com/CyberPower-CP1500PFCLCD-Sinewave-Outlets-Mini-Tower/dp/B00429N19W?th=1)

## A Few Cheap Flash Drives
- one for the server ISO (Ubuntu Server)
- one for the desktop ISO (Mint)
- one for transferring files between the client PC and the air-gapped PC
- for example:
	- [SanDisk 32GB 3-Pack Ultra USB 3.0 Flash Drive 32GB](https://www.amazon.com/SanDisk-3-Pack-Ultra-Flash-3x32GB/dp/B08HSS37H7?th=1)
