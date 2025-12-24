**Links:**

- [ZeroTier](https://www.zerotier.com/)
- [ZTNet](https://github.com/sinamics/ztnet)

ZTNet installation script on VPS server.

_The script is raw and simple, there aren't a bunch of checks and such. Tested on VPS running Debian 12._

---

This is an automatic script to install and configure the panel domain, as well as other domains (if needed) and SSL for them. But NGINX config will be **fully** customized only for the panel. But it is possible not to add additional domains at once and use a [script](https://github.com/nozsh/home-server-vps-ztnet-init/blob/main/init/init.sh) later, that will do it all by itself - `bash init/add_new.sh`

```bash
git clone https://github.com/nozsh/home-server-vps-ztnet-init ztnet && cd ztnet && bash init/init.sh
```

_Text below covers connecting a home server and a VPS to the same ZeroTier network, with the VPS working as controller and client, so `home <---> VPS`._

Create a network in the admin area. Connect to the network on the home server according to the instructions. And on the VPS run:

```bash
NET_ID="XYZ"; docker exec ztnet sh -c "cd /var/lib/zerotier-one && mkdir networks.d && cd networks.d && touch $NET_ID.conf"
```

Where `XYZ` is the network ID.

If no other domains have been added, in addition to the panel you need to edit the NGINX configs - change `proxy_pass`. Where `<ZeroTier_IP>` is the IP of the home server in ZeroTier network, `APP_PORT` is the port on which the service is running on the home server.

```bash
docker compose down && docker compose up -d && docker compose logs -f
```

And if the home server loses connect:

```bash
sudo systemctl restart zerotier-one
```

---

More details [here](https://nozsh.com/blog/en/tunnel-between-home-server-and-vps-via-zerotier/).
