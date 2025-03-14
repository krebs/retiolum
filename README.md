# retiolum

retiolum network files.

* `etc.hosts` belongs to `/etc/hosts`
* `hosts` belongs to `/etc/tinc/retiolum/hosts`

For an example config look at `example.nix`


# HOWTO join the network

## generate your public/private keypair

Create a new directory somewhere on your machine:

```
mkdir retiolum-cfg
```

Generate keypairs in that directory:

```
nix-shell -p tinc_pre --run 'tinc --config retiolum-cfg generate-keys 4096 </dev/null'
```

## add key to stockholm

The stockholm repository contains (among other things) the configuration of the
retiolum super nodes.  This configuration needs to be updated in order to add
new hosts to the network.

Checkout the repository and change into it:

```
git clone https://cgit.krebsco.de/stockholm
cd stockholm
```

Add your user and host information to `kartei/$MYNAME`, e.g. like so:

```
cp -r kartei/template kartei/$USER
$EDITOR kartei/$USER/default.nix
```

Prepare a pull-request:

```
git add kartei/$USER
git commit -m 'kartei $USER: init $MYHOST'
git format-patch origin/master..
```

This will print the file name of the formatted patch, which will be called
something like `0001-external-add-myhostname.patch` (depending on your commmit
message).  The contents of that should look something like this:

```patch
From 75785902b71f03474c446694c5e1e25cd8c3ee23 Mon Sep 1700:00:00 2001
From: myname <myname@mydomain>
Date: 23 May 12719 11:34:66 +0000
Subject: [PATCH] kartei: init $MYHOST

---
 kartei/template/default.nix | 4 ++++
 1 file changed, 4 insertions(+)

diff --git a/kartei/$MYNAME/default.nix b/kartei/$MYNAME/default.nix
new file mode 100644
index 00000000..2acf78d3
--- /dev/null
+++ b/kartei/$MYNAME/default.nix
@@ -0,0 +1,20 @@
+{
+  users.MYNAME = MYUSERSTUFF;
+  hosts.MYHOST = MYHOSTSTUFF;
+}
-- 
332.1.2
```

Of course you can also send the patch directly.
E.g. if you have sendmail configured:
```
git format-patch --stdout --to=spam@krebsco.de origin/master.. | tail -n +2 | sendmail -t
```

## ask for the patch to get merged

Join the #krebs channel on hackint.
If you don't know anything about IRC, you can just use this webirc: https://webirc.hackint.org/#ircs://irc.hackint.org/#krebs
If you are not known, introduce yourself, explain what you are doing and what you want to contribute.
Then send the formatted patch either sent via email to spam@krebsco.de, or
upload it to some pastebin (preferably https://p.krebsco.de) (use it with curl --data-binary) and share the
link to the pasted patch in #krebs.
Now some patience will be required, but you will soon receive confirmation or
change requests for your patch, and it will get deployed to the super nodes.
At this point your host will be able to join the network.
For the impatient, pinging `lassulus` or `tv` might speed up the process,
but usually we will act ASAP anyway.

## configure your nixos for retiolum

after you have been approved..

check if your pubkey file is in the current master of https://github.com/krebs/retiolum (should be in a file named after your host in the hosts folder)
look into your pubkey file and copy your ipv6 address which got autogenerated.
copy the `example.nix` to your configuration.nix, update the rev and sha256 of the retiolum fetchgit to the current master. (you have to update it everytime if new hosts join you want to connect to)
import the example.nix (you can choose a better name, like retiolum.nix) in your configuration.nix
configure your ipv6 address

inside configuration.nix:

```
imports = [
  /path/to/example.nix
];
networking.retiolum.ipv4 = "10.243.my.ip";  # optional
networking.retiolum.ipv6 = "42:0:3c35::my:ip";
services.tinc.networks.retiolum = {
  rsaPrivateKeyFile = "/path/to/tinc.rsa_key.priv";
  ed25519PrivateKeyFile = "/path/to/tinc.ed25519.priv";
};
```

## test if everything is working

ping some host on the network, for example prism.r

```
ping 42:0:ce16::1
```

## Make Firefox resolve host file entries.

go to about:config and set:

```
browser.fixup.dns_first_for_single_words = true
```

## Discover internal services

See http://wiki.r for more information.
