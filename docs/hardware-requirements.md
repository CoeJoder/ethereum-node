# Full-Node Hardware Requirements
## Node Server
- powerful, efficient, headless, always-online computer, running the Ethereum node software
- Mini PC form factor is ideal for its power efficiency
- NVMe primary disk is required for its high I/O speed
- cheaper/slower 2.5" HDD or SSD as secondary disk is sufficient for less-demanding "ancient" blockchain data
- for example:
	- [Intel NUC 10 Performance Kit – Intel Core i7 Processor (Tall Chassis)](https://www.amazon.com/gp/product/B08357VWB2/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&psc=1)
		- only drawback of this chassis is that, despite being the "tall" model, it will not fit a 15mm 2.5" 5TB HDD, so you're stuck with purchasing an expensive SSD despite not needing SSD speeds, such as the 4TB linked below
	- [32 GB (2 x16 GB) DDR4 2666 RAM](https://www.amazon.com/CORSAIR-Vengeance-Performance-260-Pin-CMSX32GX4M2A2666C18/dp/B01BGZEVHU)
	- [Western Digital SN750 2TB](https://www.amazon.com/Black-SN750-NVMe-Internal-Gaming/dp/B07M9VXSXG)
	- [SAMSUNG 870 EVO 4TB 2.5 Inch SATA III Internal SSD](https://www.amazon.com/gp/product/B08QBL36GF/ref=ppx_yo_dt_b_search_asin_title?ie=UTF8&th=1)
		- 2.5" SSDs > 4TB are astronomically more expensive, but 4TB as secondary is plenty for the foreseeable future.  Worst-case scenario: switching to external USB secondary storage in a few years (inelegant, but the I/O reqs are low enough where this would work)

## Client PC
- your laptop or desktop computer, connected to the same LAN as the node server
- this guide presumes you have Linux installed.  With minor modifications, you could also use Windows 10+ via WSL (Windows Subsystem for Linux), or Mac OS, but this is beyond the scope of this guide
- this guide will instruct you on how to create a SSH tunnel with passkey authentication for administering the node server in a secure way

## Router / Firewall
- the hub of your LAN which connects the node server & client PC together and to the internet
- a decent router which can run [OpenWRT](https://openwrt.org/)
- for example:
	- [Linksys WRT3200ACM](https://www.amazon.com/dp/B01JOXW3YE?&tag=router10-20) (*Èl Classicò Americàno*)
		- long in the tooth, but still works well.  It has dual-partition storage to house two firmware installs simultaneously and switches between them automatically during flashing, which makes tinkering much easier.  It's also widely supported with a huge userbase, so finding help on the various forums is easy
		- there are newer WiFi 6+ routers which are open source-friendly, including a variety of cheap Chinesium appliances which are popular in the "tech bro" community, but they are buggy, suffer occasional zero-day exploits ([exhibit A](https://news.ycombinator.com/item?id=41605680)) and supply-chain attacks ([exhibit B](https://archive.is/xewlX)).  I recommend sticking with *Èl Classicò Americàno* for now.  If better WiFi is needed, disable its Wifi radios and connect a separate AP
		- a viable alternative would be either a dedicated Mini PC or a pfSense/OPNSense appliance, and running pfSense/OPNSense for routing & firewall duties instead of OpenWRT, but this is out of scope for this guide

## UPS Battery Backup
- provides surge & sag protection, extending the life of the node server and router
- keeps the node server and router running during brief power outtages
- gracefully shuts-down the node server during extended power outtages
- for example:
	- [CyberPower CP1500PFCLCD](https://www.amazon.com/CyberPower-CP1500PFCLCD-Sinewave-Outlets-Mini-Tower/dp/B00429N19W?th=1)
