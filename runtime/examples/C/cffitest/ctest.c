#include <stdio.h>

#include <tapasco.h>

void handle_error() {
    int l = tapasco_last_error_length();
    char* buf = (char*)malloc(sizeof(char) * l);
    tapasco_last_error_message(buf, l);
    printf("ERROR: %s\n", buf);
    free(buf);
}

int main() {
    int ret = 0;

    tapasco_init_logging();
    TLKM *t = tapasco_tlkm_new();
    if(t == 0) {
        handle_error();
        ret = -1;
        goto finish;
    }

    char tlkm_version[32];
    if(tapasco_tlkm_version(t, tlkm_version, 32) != 0) {
        handle_error();
        ret = -1;
        goto finish_tlkm;
    }

    printf("TLKM Version: %s\n", tlkm_version);

    int num_devices = 0;
    if((num_devices = tapasco_tlkm_device_len(t)) < 0) {
        handle_error();
        ret = -1;
        goto finish_tlkm;
    }

    printf("Got %d devices.\n", num_devices);

    if(num_devices > 0) {
        DeviceInfo *dev_info = malloc(sizeof(DeviceInfo) * num_devices);
        if(tapasco_tlkm_devices(t, dev_info, num_devices) != 0) {
            handle_error();
            ret = -1;
            goto finish_tlkm;
        }
        for(int i = 0; i < num_devices; ++i) {
            printf("Device %d => Name %s, Vendor %d, Product %d\n", i, dev_info[i].name, dev_info[i].product, dev_info[i].vendor);
        }
        tapasco_tlkm_devices_destroy(dev_info, num_devices);
        free(dev_info);

        for(int i = 0; i < num_devices; ++i) {
            Device *d = 0;
            if((d = tapasco_tlkm_device_alloc(t, i)) == 0) {
                handle_error();
                ret = -1;
                goto finish_tlkm;
            }

            if(tapasco_device_access(d, TlkmAccessExclusive) < 0) {
                handle_error();
                ret = -1;
                goto finish_tlkm;
            }

            Job* j = tapasco_device_acquire_pe(d, 14);
            if(j == 0) {
                handle_error();
                ret = -1;
                goto finish_tlkm;
            }

            JobList* jl = tapasco_job_param_new();
            if(jl == 0) {
                handle_error();
                ret = -1;
                goto finish_tlkm;
            }

            tapasco_job_param_single64(1, jl);

            if(tapasco_job_start(j, jl) < 0) {
                handle_error();
                ret = -1;
                goto finish_tlkm;
            }

            if(tapasco_job_release(j, true) < 0) {
                handle_error();
                ret = -1;
                goto finish_tlkm;
            }

            tapasco_tlkm_device_destroy(d);
        }
    }

finish_tlkm:
    tapasco_tlkm_destroy(t);
finish:
    return ret;
}