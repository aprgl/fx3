#include "fx3.h"
#include <stdio.h>
#include <string.h>
#include <stdint.h>

fx3_usb fx3;

int fx3_init(){

    int error;
    ssize_t device_count;

    // Init libusb
    error = libusb_init(NULL);
    int level = debug_libusb_level();
    libusb_set_debug(NULL, level);
    if(error){
        printf("Failed to initialise libusb. Error code:%d\n",error);
        return(error);
    }

    // Get the list of usb devices
    device_count = libusb_get_device_list(NULL, &fx3.devs);
    if (device_count < 0){
        printf("Crazy impossible? Error - no USB devices found\n");
        return (int)device_count;
    }
    
    // Select our device
    fx3.dev_handle = libusb_open_device_with_vid_pid(NULL, FX3_VENDOR_ID, FX3_DEVICE_ID);
    if(fx3.dev_handle == NULL){
        printf("Failed to open device %hhX:%hhX\n", FX3_VENDOR_ID, FX3_DEVICE_ID);
    }

    // Release the list
    libusb_free_device_list(fx3.devs, 1);

    // Check to see if our device has a kernel driver attahed
    if(libusb_kernel_driver_active(fx3.dev_handle, 0) == 1) {
        printf("Kernel Driver Attached!\n");
        if(libusb_detach_kernel_driver(fx3.dev_handle, 0) == 0){
            printf("Kernel Driver Detached!\n");
        }
    }

    // Call dibs on our device's interface 0
    error = libusb_claim_interface (fx3.dev_handle, 0);
    if(error){
        printf("Can't claim interface. Bailing out with error code %d\n",error);
        return error;
    }

    printf("Speed reported is: %d\n", libusb_get_device_speed(libusb_get_device(fx3.dev_handle)));
    return 0;
}

int fx3_bulk_write(uint8_t* buffer, uint16_t length){

    /* TODO Make if(debug)
    printf("Writing data to fx3\n");
    for(int i=0; i<length; i++){
        printf("0x%hhx ", buffer[i]);
    }
    printf("\n");
    */
    

    int transferred = 0;
    int error = libusb_bulk_transfer(fx3.dev_handle, FX3_BULK_ENDPOINT_OUT, buffer, length, &transferred, USB_TIMEOUT);
    if(error){
        printf("Write Error. Error code: %d\n",error);
    }else if(transferred != length){
        printf("Shattered! Incomplete data transfer. Expected: %d - Actual: %d\n",length,transferred);
    }
    //fflush(stdout);
    //printf("TX Transferred %d\n",transferred);
    
    return transferred;
}

int fx3_bulk_read(uint8_t* buffer, uint16_t length){

    //printf("Reading data from interface\n");
    memset(buffer, 0, length);
    /*
    printf("Data RX Buffer Before RX:\n");
    for(int i=0; i<length; i++){
        printf("0x%hhx ", buffer[i]);
    }
    */
    int transferred;
    int error = libusb_bulk_transfer(fx3.dev_handle, FX3_BULK_ENDPOINT_IN, buffer, length, &transferred, USB_TIMEOUT);
    if(error){
        printf("Read Error. Error code: %d\n",error);
    }
    /*else if(transferred != length){
        printf("Shattered! Incomplete data transfer. Expected: %d - Actual: %d\n",length,transferred);
    }
    printf("RX Transferred %d\n",transferred);
    */
    /*
    printf("Data RX Buffer After - recieved from fx3:\n");
    for(int i=0; i<length; i++){
        printf("0x%hhx ", buffer[i]);
    }
    printf("\n");
    fflush(stdout);
    */
    
    return transferred;
}

int fx3_bulk_read_timeout(uint8_t* buffer, uint16_t length, int timeout){

    memset(buffer, 0, length);
    int transferred;
    int error = libusb_bulk_transfer(fx3.dev_handle, FX3_BULK_ENDPOINT_IN, buffer, length, &transferred, timeout);
    // If Debug()
    /*
    if(error){
        printf("Read Error. Error code: %d\n",error);
    }else if(transferred != length){
        printf("Shattered! Incomplete data transfer. Expected: %d - Actual: %d\n",length,transferred);
    }
    printf("RX Transferred %d\n",transferred);
    
    return transferred;
    */
}

/*
Need to check what the FX3 Register size is and update length to match total of FPGA & FX3.
*/
int fx3_clear_buffers(){

    //printf("Clearing FX3 Registers\n");
    //printf("Speed reported is: %d\n", libusb_get_device_speed(libusb_get_device(fx3.dev_handle)));
    int length = 4096;
    uint8_t buffer[4096] = {0};
    int transferred = 0;
    int error = 0;
    do {
        transferred = 0;
        error = libusb_bulk_transfer(fx3.dev_handle, FX3_BULK_ENDPOINT_IN, buffer, length, &transferred, USB_TIMEOUT);
        if(error){
            printf("Read Error. Error code: %d\n",error);
        }
        if(transferred != length){
            printf("Shattered! Incomplete data transfer. Expected: %d - Actual: %d\n",length,transferred);
        }
        printf("RX Transferred %d\n",transferred);
        printf("Error: %d\n",error);
    } while( error != LIBUSB_ERROR_TIMEOUT || transferred != 0 );
    /* 
    printf("Data RX Buffer After - recieved from fx3:\n");
    for(int i=0; i<length; i++){
        printf("0x%hhx ", buffer[i]);
    }
    printf("\n");
    */
    fflush(stdout);
    
    return transferred;
}

void fx3_set_debug(){
    // 0-None, 1-Error, 2-Warn, 3-Info
    int level = debug_libusb_level();
    libusb_set_debug(NULL, level);
}

int fx3_close(){

    // Release our device
    int error = libusb_release_interface(fx3.dev_handle, 0);
    if(error) {
        printf("Cannot release interface. Error code %d",error);
        return error;
    }
    
    // Close our device and libusb
    libusb_close(fx3.dev_handle);
    libusb_exit(NULL);
    return 0;
}