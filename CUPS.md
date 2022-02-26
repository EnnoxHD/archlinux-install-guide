# CUPS
- is a printing service
- allows for PDF output printing

## Install
```bash
aurman -Syu cups cups-pdf
```

### Optional: 32-bit support
```bash
aurman -Syu lib32-libcups
```

## Configure
```bash
sudo nano /etc/cups/cups-pdf.conf
```
Change content:
```text
Out /home/${USER}/Downloads
```

## Start service
```bash
sudo systemctl start cups.service
sudo systemctl enable cups.service
```
