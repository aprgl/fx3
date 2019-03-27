#ifndef FX3_H
#define FX3_H

#include <stdint.h>
#include <libusb-1.0/libusb.h>

#define FX3_VENDOR_ID 0x04b4
#define FX3_DEVICE_ID 0x00f1
#define FX3_BULK_ENDPOINT_OUT 0x01
#define FX3_BULK_ENDPOINT_IN 0x81
#define USB_TIMEOUT 1000 // In miliseconds

typedef struct{
    libusb_device_handle *dev_handle;
    libusb_device **devs;
}fx3_usb;

extern fx3_usb fx3;

int fx3_init();
void fx3_set_debug();
int fx3_clear_buffers();
int fx3_bulk_write(uint8_t* buffer, uint16_t length);
int fx3_bulk_read(uint8_t* buffer, uint16_t length);
int fx3_bulk_read_timeout(uint8_t* buffer, uint16_t length, int timeout);
int fx3_close();

#endif