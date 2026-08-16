/*
 * Generates a deterministic, non-case E01 fixture without stored media hashes.
 *
 * The byte at media offset N is ((N * 31) + 17) modulo 251. The writer
 * intentionally does not call libewf_handle_set_md5_hash() or
 * libewf_handle_set_sha1_hash(). The resulting fixture exercises the
 * readable-without-a-stored-hash path; it is not evidence.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <libewf.h>

#define FIXTURE_MEDIA_SIZE ((uint64_t) 2621440)
#define FIXTURE_SEGMENT_SIZE ((uint64_t) 1048576)
#define FIXTURE_BUFFER_SIZE 65536

static void print_error(libewf_error_t *error)
{
    if (error != NULL)
    {
        libewf_error_backtrace_fprint(error, stderr);
        libewf_error_free(&error);
    }
}

int main(int argc, char *argv[])
{
    libewf_error_t *error = NULL;
    libewf_handle_t *handle = NULL;
    char *filenames[1];
    uint8_t buffer[FIXTURE_BUFFER_SIZE];
    uint64_t media_offset = 0;
    size_t buffer_index = 0;
    size_t write_size = 0;
    ssize_t write_count = 0;
    int close_result = 0;
    int exit_code = EXIT_FAILURE;

    if (argc != 2)
    {
        fprintf(stderr, "Usage: ewf_fixture_writer.exe TARGET_BASE\n");
        return EXIT_FAILURE;
    }
    filenames[0] = argv[1];

    if (libewf_handle_initialize(&handle, &error) != 1)
    {
        print_error(error);
        return EXIT_FAILURE;
    }
    if (libewf_handle_open(handle, filenames, 1, LIBEWF_OPEN_WRITE, &error) != 1)
    {
        goto on_error;
    }
    if (libewf_handle_set_format(handle, LIBEWF_FORMAT_ENCASE6, &error) != 1 ||
        libewf_handle_set_media_size(handle, FIXTURE_MEDIA_SIZE, &error) != 1 ||
        libewf_handle_set_maximum_segment_size(
            handle, FIXTURE_SEGMENT_SIZE, &error) != 1)
    {
        goto on_error;
    }

    while (media_offset < FIXTURE_MEDIA_SIZE)
    {
        write_size = FIXTURE_BUFFER_SIZE;
        if (FIXTURE_MEDIA_SIZE - media_offset < write_size)
        {
            write_size = (size_t) (FIXTURE_MEDIA_SIZE - media_offset);
        }
        for (buffer_index = 0; buffer_index < write_size; buffer_index++)
        {
            buffer[buffer_index] = (uint8_t)
                ((((media_offset + buffer_index) * 31) + 17) % 251);
        }
        write_count = libewf_handle_write_buffer(
            handle, buffer, write_size, &error);
        if (write_count != (ssize_t) write_size)
        {
            goto on_error;
        }
        media_offset += write_size;
    }
    close_result = libewf_handle_close(handle, &error);
    if (close_result != 0)
    {
        goto on_error;
    }
    if (libewf_handle_free(&handle, &error) != 1)
    {
        print_error(error);
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;

on_error:
    print_error(error);
    if (handle != NULL)
    {
        libewf_handle_close(handle, NULL);
        libewf_handle_free(&handle, NULL);
    }
    return exit_code;
}
