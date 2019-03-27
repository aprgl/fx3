# fx3
USB interface for FPGA using a the Cypress FX3

# Unit Tests
The testbenches are designed to work with https://github.com/VUnit/vunit
python run.py to run the unit test

# Hardware Testing
The system is currently being tested using the following:
## FX3 Hardware
Cypress Easy USB 3 Dev Kit (CYUSB3KIT_003) and HSMC Adapter (CYUSB3ACC_006)
## FX3 Firmware
The FX3 is currently being loaded with SF_loopback.img from AN65974 using cyusb_linux_1.0.5 from Cypress.
## FPGA Hardware
Cyclone IV on the DE2-115 Dev Kit

#Useful Links
libusb error codes: http://libusb.sourceforge.net/api-1.0/group__libusb__misc.html