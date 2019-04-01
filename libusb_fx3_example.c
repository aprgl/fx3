#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include  <signal.h> // For Ctrl-C Catch

#include "fx3.h"


void INThandler(int sig);
float bit_error_rate_test(int test_length);

int main(){

    // Setup our Ctrl-C Catch and shutdown
    signal(SIGINT, INThandler);

    // Connect to the FX3
    fx3_init();

    // Run a Bit Error Rate test
    bit_error_rate_test(3);

    // Disconnect from the FX3
    fx3_close();

    return 0;
}

void  INThandler(int sig){
    signal(sig, SIG_IGN);
    printf("You can silence me but there will be others.\n");
    printf("Semper fidelis tyrannosaurus.\n"); // Always faithful, terrible lizrd.
    fx3_close();
    exit(0);
}

float bit_error_rate_test(int test_length){
    
    printf("Starting Bit Error Rate Test - %d iteration(s).\n", test_length);
    
    float bit_error_rate = 0; // %
    uint32_t successful = 0;
    uint32_t failed = 0;
    srand(time(0));

    uint8_t tx_buffer[FX3_MAX_PAYLOAD];

    fx3_clear_buffers();
    
    for(int i=0; i<test_length; i++){

        for(int i=0; i<FX3_MAX_PAYLOAD; i++){
            tx_buffer[i] = rand();
        }
        int bytes_sent = fx3_bulk_write(tx_buffer, FX3_MAX_PAYLOAD);

        uint8_t rx_buffer[FX3_MAX_PAYLOAD];
        
        for(int i=0; i<FX3_MAX_PAYLOAD; i++){
            rx_buffer[i] = 0;
        }
        int bytes_recieved = fx3_bulk_read(rx_buffer, FX3_MAX_PAYLOAD);

        uint32_t rogue_bits = 0;
        uint32_t a_buff[FX3_MAX_PAYLOAD/4];
        uint32_t b_buff[FX3_MAX_PAYLOAD/4];
        memcpy(a_buff, tx_buffer, FX3_MAX_PAYLOAD);
        memcpy(b_buff, rx_buffer, FX3_MAX_PAYLOAD);

        for(int i=0; i<FX3_MAX_PAYLOAD/4; i++){
            uint32_t temp = a_buff[i] ^ b_buff[i];
            int outliers = __builtin_popcount(temp);
            rogue_bits += outliers;

            if(outliers != 0){
                printf("Rogue Bits Detected at dword %d TX:0x%08x RX:0x%08x - \
                    Rogue Bit Count:%d\n", i, a_buff[i], b_buff[i], outliers);
            }
        }
        
        if (bytes_sent == 0 || bytes_recieved == 0)
            rogue_bits = FX3_MAX_PAYLOAD*8;
        failed += rogue_bits;
        successful += (FX3_MAX_PAYLOAD*8)-rogue_bits;
    
        printf("\rsuccessful: %u failed: %u %.2f.", successful, failed, 
            (float)failed/(successful+failed));
        fflush(stdout);

    }
    
    bit_error_rate = ((float)failed/(successful+failed));
    printf("\nBit Error Rate: %.2f%%\n\n", bit_error_rate*100);
    return bit_error_rate;
}
