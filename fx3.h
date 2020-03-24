#ifndef FX3_H
#define FX3_H

#include <stdint.h>
#include <libusb-1.0/libusb.h>

#define FX3_VENDOR_ID 0x04b4
#define FX3_DEVICE_ID 0x00f1
#define FX3_BULK_ENDPOINT_OUT 0x01
#define FX3_BULK_ENDPOINT_IN 0x81
#define USB_TIMEOUT 1000 // In milliseconds

#define FX3_MAX_PAYLOAD 4096 // USB3 Max Payload Size
#define USB_RX_BUFFER_DEPTH 8192 // USB3 Max Payload Size

typedef struct{
    libusb_device_handle *dev_handle;
    libusb_device **devs;
}fx3_usb;

// Probably should just forward on LIBUSB error codes instead of this 
enum fx3_error{
	FX3_SUCCESS = 0,

	FX3_ERROR_LIBUSB = -1

};

extern fx3_usb fx3;

int fx3_init();
void fx3_set_debug();
void fx3_print_speed();
int fx3_clear_buffers();
int fx3_bulk_write(uint8_t* buffer, uint16_t length);
int fx3_bulk_read(uint8_t* buffer, uint16_t length);
int fx3_bulk_read_timeout(uint8_t* buffer, uint16_t length, int timeout);
int fx3_close();

#endif
