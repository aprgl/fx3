#include "fx3.h"
#include <stdio.h>
#include <string.h>
#include <stdint.h>

fx3_usb fx3;

int fx3_init(){

    int error;
    ssize_t device_count;

    #ifdef DEBUG
        libusb_set_debug(NULL, 3);
    #endif

    // Init libusb
    error = libusb_init(NULL);
    if(error){
        return(FX3_ERROR_LIBUSB); // Failed to initialize libusb.
    }

    // Get the list of usb devices
    device_count = libusb_get_device_list(NULL, &fx3.devs);
    if (device_count < 0){
        return FX3_ERROR_LIBUSB; // Crazy impossible? No USB devices found
    }
    
    // Select our device
    fx3.dev_handle = libusb_open_device_with_vid_pid(NULL,
                                                FX3_VENDOR_ID, FX3_DEVICE_ID);
    if(fx3.dev_handle == NULL){
        return FX3_ERROR_LIBUSB; // Failed to open device
    }

    // Release the list
    libusb_free_device_list(fx3.devs, 1);

    // Check to see if our device has a kernel driver attached and try to detach
    if(libusb_kernel_driver_active(fx3.dev_handle, 0) == 1) {
        error = libusb_detach_kernel_driver(fx3.dev_handle, 0);
        if(error){
            return FX3_ERROR_LIBUSB; // Failed to detach kernel driver
        }
    }

    // Call dibs on our device's interface 0
    error = libusb_claim_interface (fx3.dev_handle, 0);
    if(error){
        return FX3_ERROR_LIBUSB; // Can't claim interface. Bailing out
    }

    return FX3_SUCCESS;
}

int fx3_bulk_write(uint8_t* buffer, uint16_t length){

    #ifdef DEBUG
        printf("Writing data to fx3\n");
        for(int i=0; i<length; i++){
            printf("0x%hhx ", buffer[i]);
        }
        printf("\n");
    #endif
    

    int transferred = 0;
    int error = libusb_bulk_transfer(fx3.dev_handle, FX3_BULK_ENDPOINT_OUT,
                                    buffer, length, &transferred, USB_TIMEOUT);
    if(error){
        return FX3_ERROR_LIBUSB;
    }

    #ifdef DEBUG
        fflush(stdout);
        printf("TX Transferred %d\n",transferred);
    #endif

    return transferred;
}

int fx3_bulk_read(uint8_t* buffer, uint16_t length){

    memset(buffer, 0, length);
    int transferred;
    int error = libusb_bulk_transfer(fx3.dev_handle, FX3_BULK_ENDPOINT_IN,
                                    buffer, length, &transferred, USB_TIMEOUT);
    if(error){
        return error;//FX3_ERROR_LIBUSB;
    }

    #ifdef DEBUG
        printf("Data RX Buffer After - received from fx3:\n");
        for(int i=0; i<length; i++){
            printf("0x%hhx ", buffer[i]);
        }
        printf("\n");
        fflush(stdout);
        printf("RX Transferred %d\n",transferred);
    #endif
    
    return transferred;
}

int fx3_bulk_read_timeout(uint8_t* buffer, uint16_t length, int timeout){

    memset(buffer, 0, length);
    int transferred;
    int error = libusb_bulk_transfer(fx3.dev_handle, FX3_BULK_ENDPOINT_IN,
                                    buffer, length, &transferred, timeout);
    
    if(error){
        return FX3_ERROR_LIBUSB;
    }

    #ifdef DEBUG
        if(transferred != length){
            printf("Shattered! Incomplete data transfer. \
                Expected: %d - Actual: %d\n",length,transferred);
        }
        printf("RX Transferred %d\n",transferred);
    #endif

    return transferred;
}


// Todo: Check what the FX3 Register size is and update 
//    length to match total of FPGA & FX3.
int fx3_clear_buffers(){

    int length = 4096;
    uint8_t buffer[4096] = {0};
    int transferred = 0;
    int error = 0;
    transferred = 0;
    libusb_bulk_transfer(fx3.dev_handle, FX3_BULK_ENDPOINT_IN,
                                buffer, length, &transferred, USB_TIMEOUT);
    
    return transferred;
}

void fx3_set_debug(){
    // 0-None, 1-Error, 2-Warn, 3-Info
    libusb_set_debug(NULL, 3);
}

int fx3_get_speed(){
    // LIBUSB_SPEED_UNKNOWN = 0, LIBUSB_SPEED_LOW = 1, LIBUSB_SPEED_FULL = 2 
    // LIBUSB_SPEED_HIGH = 3, LIBUSB_SPEED_SUPER = 4 
    return libusb_get_device_speed(libusb_get_device(fx3.dev_handle));
}

int fx3_close(){

    // Release our device
    int error = libusb_release_interface(fx3.dev_handle, 0);
    if(error) {
        return FX3_ERROR_LIBUSB;
    }
    
    // Close our device and libusb
    libusb_close(fx3.dev_handle);
    libusb_exit(NULL);
    return FX3_SUCCESS;
}