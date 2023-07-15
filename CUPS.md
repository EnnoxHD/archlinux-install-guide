# CUPS
- is a printing service
- allows for virtual PDF printing

## Install
```bash
aurman -Syu cups cups-pdf
```

### Optional: 32-bit support
```bash
aurman -Syu lib32-libcups
```

## Start service
```bash
sudo systemctl start cups.service
sudo systemctl enable cups.service
```

## Configure

### Output location
```bash
sudo nano /etc/cups/cups-pdf.conf
```
Change content:
```text
Out /home/${USER}/Downloads
```

### Add virtual pdf printer
1. Go to [http://localhost:631/](http://localhost:631/)
1. Go to `Administration` and click on `Add printer`
1. Login on the website as the `root` user
1. Choose `CUPS-PDF` in the `Local printers` group and click `Next`
1. Set the name and description and click `Next`
    - `Name`: `cups-pdf`
    - `Description`: `cups-pdf`
    - `Location`: leave empty
    - `Connection`: `cups-pdf:/`
    - `Share`: `[ ]`
1. Choose the manifacturer and model and click `Add printer`
    - `Manifacturer`: `Generic` and click `Next`
    - `Model`: `Generic CUPS-PDF Printer (w/ options) (en)`

### Configure virtual pdf printer
1. Open the GNOME Control Center and go to `Printers`
1. Unlock the settings page
1. On the printer named `cups-pdf` go to the options and set the following
    - `Page Setup`
        - `Pages per Sheet`: `1`
        - `Rotation`: `Portrait`
        - `Page Size`: `A4`
    - `Image Quality`
        - `Resolution`: `300 DPI`
    - `Extra`
        - `PDF version`: `1.5`
        - `Truncate output filename to`: `64 Characters`
        - `Label outputfiles`: `Label only untitled documents with job-id`
        - `Prefer title from`: `Title in postscript document`
        - `Log level`: `Debug, error and status messages`

### Add printer
- Model: Canon PIXMA TS5355a

1. Install driver `aurman -Syu canon-pixma-ts5055-complete`
1. Run `cnijlgmon3` to get the printer address, e.g. `cnijbe2://Canon/?port=usb&serial=01DE95`
1. For available printer models search in `/usr/share/cups/model/*.ppd`
1. Run `sudo lpadmin -p cups-Canon_TS5355a -m canonts5300.ppd -v 'cnijbe2://Canon/?port=usb&serial=01DE95' -E` to add the printer to the cups configuration
