# fx3
A USB interface for an FPGA using a the Cypress FX3 device.

# Unit Tests
#### VHDL
The VHDL testbenches are designed to work with [vunit](https://github.com/VUnit/vunit)

*python run.py* to run the unit test

# Hardware Testing
The system is currently being tested using the following:
#### FX3 Hardware
Cypress Easy USB 3 Dev Kit [CYUSB3KIT_003](https://www.cypress.com/documentation/development-kitsboards/cyusb3kit-003-ez-usb-fx3-superspeed-explorer-kit) and HSMC Adapter [CYUSB3ACC_006](https://www.cypress.com/documentation/development-kitsboards/cyusb3acc-006-hsmc-interconnect-board-ez-usb-fx3-superspeed)
#### FX3 Firmware
The FX3 is currently being loaded with SF_loopback.img from [AN65974](https://www.cypress.com/documentation/application-notes/an65974-designing-ez-usb-fx3-slave-fifo-interface) using cyusb_linux_1.0.5 from Cypress.
#### FPGA Hardware
Cyclone IV on the [DE2-115 Dev Kit](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=502)

# Useful Links
[libusb error codes](http://libusb.sourceforge.net/api-1.0/group__libusb__misc.htmlhttps://www.cypress.com/documentation/development-kitsboards/cyusb3kit-003-ez-usb-fx3-superspeed-explorer-kit)
