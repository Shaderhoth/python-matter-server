# Python Matter Server

This project implements a Matter Controller Server over WebSockets using the
[official Matter (formerly CHIP) SDK](https://github.com/project-chip/connectedhomeip)
as a base and provides both a server and client implementation.

The goal of this project is primarily to have Matter support in Home Assistant
but its universal approach makes it suitable to be used in other projects too.

[![Python Matter Server - A library from the Open Home Foundation](https://www.openhomefoundation.org/badges/python-matter-server.png)](https://www.openhomefoundation.org/)

## Support

Got questions?

You have several options to get them answered:

- The Home Assistant [Community Forum](https://community.home-assistant.io/).
- The Home Assistant [Discord Chat Server](https://discord.gg/c5DvZ4e).
- Join [the Reddit subreddit in /r/homeassistant](https://reddit.com/r/homeassistant).

If you experience issues using Matter with Home Assistant, please open an issue
report in the [Home Assistant Core repository](https://github.com/home-assistant/core/issues/new/choose).

You may also open issues in this repository if you are absolutely sure that your
issue is related to the Matter Server component.

## Installation

We strongly recommend using Home Assistant OS along with the official Matter
Server add-on to use Matter with Home Assistant. The Matter integration
automatically installs the Python Matter Server add-on. Please refer to the
[Home Assistant documentation](https://www.home-assistant.io/integrations/matter/).
Home Assistant OS has been tested and tuned to be used with Matter and Thread,
which makes this combination the best tested and largely worry free
environment.

If you still prefer a self-managed container installation, we do offer an
official container image. Please keep in mind that you might experience
communication issues with Matter devices, especially Thread based devices.
This is mostly because the container installation uses host networking, and
relies on the networking managed by your operating system.

### Requirements to communicate with Wi-Fi/Ethernet based Matter devices

Make sure you run the container on the host network. The host network
interface needs to be in the same network as the Android/iPhone device
you are using for commissioning. Matter uses link-local multicast protocols
which do not work across different LANs or VLANs.

The host network interface needs IPv6 support enabled.

### Requirements to communicate with Thread devices through Thread border routers

For communication through Thread border routers which are not running on the same
host as the Matter Controller server to work, IPv6 routing needs to be properly
working. IPv6 routing is largely setup automatically through the IPv6 Neighbor
Discovery Protocol, specifically the Route Information Options (RIO). However,
if IPv6 Neighbor Discovery RIO's are processed, and processed correctly depends on the network
management software your system is using. There may be bugs and caveats in
processing this Route Information Options.

In general, make sure the kernel option `CONFIG_IPV6_ROUTER_PREF` is enabled and
that IPv6 forwarding is disabled (sysctl variable `net.ipv6.conf.all.forwarding`).
If IPv6 forwarding is enabled, the Linux kernel doesn't employ reachability
probing (RFC 4191), which can lead to longer outages (up to 30min) until
network changes are detected.

If you are using NetworkManager, make sure to use at least NetworkManager 1.42.
Previous versions lose track of routes and stale routes can lead to unreachable
Thread devices. All current released NetworkManager versions can't handle
multiple routes to the same network properly. This means if you have multiple
Thread border routers, the fallback won't work immediately (see [NetworkManager
issue #1232](https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/issues/1232)).

We currently don't have experience with systemd-networkd. It seems to have its
own IPv6 Neighbor Discovery Protocol handling.

If you don't use NetworkManager or systemd-networkd, you can use the kernel's
IPv6 Neighbor Discovery Protocol handling.

Make sure the kernel options `CONFIG_IPV6_ROUTE_INFO` is enabled and the
following sysctl variables are set:

```
sysctl -w net.ipv6.conf.wlan0.accept_ra=1
sysctl -w net.ipv6.conf.wlan0.accept_ra_rt_info_max_plen=64
```

If your system has IPv6 forwarding enabled (not recommended, see above), you'll
have to use `2` for the accept_ra variable. See also the [Thread Border Router - Bidirectional IPv6 Connectivity and DNS-Based Service Discovery codelab](https://openthread.io/codelabs/openthread-border-router#6).

### Running the Matter Server using container image

With the following command you can run the Matter Server in a container using
Docker. The Matter network data (fabric information) are stored in a newly
created directory `data` in the current directory. Adjust the command to
choose another location instead.

```
mkdir data
docker run -d \
  --name matter-server \
  --restart=unless-stopped \
  --security-opt apparmor=unconfined \
  -v $(pwd)/data:/data \
  --network=host \
  ghcr.io/shaderhoth/custom-python-matter-server:stable
```

> [!NOTE]
> The container has a default command line set (see Dockerfile). If you intend to pass additional arguments, you have to pass the default command line as well.

To use local commissioning with Bluetooth, make sure to pass the D-Bus socket as well:
```
docker run -d \
  --name matter-server \
  --restart=unless-stopped \
  --security-opt apparmor=unconfined \
  -v $(pwd)/data:/data \
  -v /run/dbus:/run/dbus:ro \
  --network=host \
  ghcr.io/shaderhoth/custom-python-matter-server:stable --storage-path /data --paa-root-cert-dir /data/credentials --bluetooth-adapter 0
```

### Running using Docker compose

```sh
docker compose up -d
docker compose logs -f
```

NOTE: Both Matter and this implementation are in an early state and features are probably missing or could be improved. See our [development notes](#development) how you can help out, with development and/or testing.

### Websocket commands

This list is not intended to be complete, for a complete oversight see the client implementation.

**Set WiFi credentials**

Inform the controller about the WiFi credentials it needs to send when commissioning a new device.

```json
{
  "message_id": "1",
  "command": "set_wifi_credentials",
  "args": {
    "ssid": "wifi-name-here",
    "credentials": "wifi-password-here"
  }
}
```

**Set Thread dataset**

Inform the controller about the Thread credentials it needs to use when commissioning a new device.

```json
{
  "message_id": "1",
  "command": "set_thread_dataset",
  "args": {
    "dataset": "put-credentials-here"
  }
}
```

**Commission with code**

Commission a new device. For WiFi or Thread based devices, the credentials need to be set upfront, otherwise, commissioning will fail. Supports both QR-code syntax (MT:...) and manual pairing code as string.
The controller will use bluetooth for the commissioning of wireless devices. If the machine running the Python Matter Server controller lacks Bluetooth support, commissioning will only work for devices already connected to the network (by cable or another controller).

Matter QR-code
```json
{
  "message_id": "2",
  "command": "commission_with_code",
  "args": {
    "code": "MT:Y.ABCDEFG123456789"
  }
}
```

Manual pairing code
```
{
  "message_id": "2",
  "command": "commission_with_code",
  "args": {
    "code": "35325335079",
    "network_only": true
  }
}
```

**Open Commissioning window**

Open a commissioning window to commission a device present on this controller to another.
Returns code to use as discriminator.

```json
{
  "message_id": "2",
  "command": "open_commissioning_window",
  "args": {
    "node_id": 1
  }
}
```

**Get Nodes**

Get all nodes already commissioned on the controller.

```json
{
  "message_id": "2",
  "command": "get_nodes"
}
```

**Get Node**

Get info of a single Node.

```json
{
  "message_id": "2",
  "command": "get_node",
  "args": {
    "node_id": 1
  }
}
```

**Start listening**

When the start_listening command is issued, the server will dump all existing nodes. From that moment on all events (including node attribute changes) will be forwarded.

```json
{
  "message_id": "3",
  "command": "start_listening"
}
```

**Send a command**

Here is an example of turning on a switch (OnOff cluster)

```json
{
  "message_id": "example",
  "command": "device_command",
  "args": {
    "endpoint_id": 1,
    "node_id": 1,
    "payload": {},
    "cluster_id": 6,
    "command_name": "On"
  }
}
```

**Python script to send a command**

Because we use the datamodels of the Matter SDK, this is a little bit more involved.
Here is an example of turning on a switch:

```python
import json

# Import the CHIP clusters
from chip.clusters import Objects as clusters

# Import the ability to turn objects into dictionaries, and vice-versa
from matter_server.common.helpers.util import dataclass_from_dict,dataclass_to_dict

command = clusters.OnOff.Commands.On()
payload = dataclass_to_dict(command)


message = {
    "message_id": "example",
    "command": "device_command",
    "args": {
        "endpoint_id": 1,
        "node_id": 1,
        "payload": payload,
        "cluster_id": command.cluster_id,
        "command_name": "On"
    }
}

print(json.dumps(message, indent=2))
```
You can also provide parameters for the cluster commands. Here's how to change the brightness for example:

```python
command = clusters.LevelControl.Commands.MoveToLevelWithOnOff(
  level=int(value), # provide a percentage
  transitionTime=0, # in seconds
)
```

### Note when using Thread based Matter devices

When communicating with Thread devices through a non-local Thread border router,
your host must process ICMPv6 Router Advertisements. See the [openthread.io
Bidirectional IPv6 Connectivity code labs](https://openthread.io/codelabs/openthread-border-router#6)
on how-to setup your host correctly. Note that NetworkManager has its own ICMPv6
Router Advertisement processing. A recent version of NetworkManager is
necessary, and there are still known issues (see NetworkManager issue
[#1232](https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/issues/1232)).

The Home Assistant Operating System 10 and newer correctly processes ICMPv6
Router Advertisements.

## Development

Want to help out with development, testing, and/or documentation? Great! As both this project and Matter keeps evolving and more and more devices are available with actual Matter support, there will be a lot to improve. Reach out to us on discord if you want to help out.

### Setting up your development environment

**For enabling Matter support within Home Assistant, please refer to the Home Assistant documentation. These instructions are for development only!**

Development is only possible on a (recent) Linux or MacOS machine. Other operating systems are not supported.

- Download/clone the repo to your local machine.
- Set-up the development environment: `scripts/setup.sh`

You can check out the example script in the scripts folder for generic directions to run the client and server.

To just run the server, you can run: `python -m matter_server.server`

The server runs a Matter Controller and includes all logic for storing node information, interviews and subscriptions. To interact with this controller we've created a small Websockets API with an RPC-like interface. The library contains a client as reference implementation which in turn is used by Home Assistant. Splitting the server from the client allows the scenario where multiple consumers can communicate to the same Matter fabric and the Matter fabric can keep running while the consumer (e.g. Home Assistant is down).

### Python client library only

There is also a Python client library hosted in this repository (used by Home Assistant), which consumes the Websockets API published from the server.

The client library has a dependency on the chip/matter clusters package which contains all (Cluster) models and this package is os/platform independent. The server library depends on the Matter Core SDK (still named CHIP) which is architecture and OS specific. We build (and publish) wheels for Linux (amd64 and aarch64) to pypi but for other platforms (like Macos) you will need to build those wheels yourself using the exact same version of the SDK as we use for the clusters package. Take a look at our build script for directions: https://github.com/home-assistant-libs/chip-wheels/blob/main/.github/workflows/build.yaml

To only install the client part: `pip install custom-python-matter-server`
