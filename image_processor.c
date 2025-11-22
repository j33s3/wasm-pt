#include <emscripten/emscripten.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// from libExif-pt
#include <exif_parser.h>
#include <format_reader.h>

#include <avif/avif.h> // from libavif
#include <jpeglib.h>   // from libjpeg

///////////// * ////////////
// **** EXIF DECODER **** //
///////////// * ////////////

// Example recieves raw bytes of an image and size
// Returns the number of bytes in the processed image (for demo)
int process_image(uint8_t data, int length) {
  // TODO: validate, strip EXIF, convert image
  return length;
}

////////// * //////////
// **** ENCODER **** //
////////// * //////////

EMSCRIPTEN_KEEPALIVE
bool encodeToAVIF(avifRGBImage *rgb, avifRWData *output) {
  avifImage *avif = avifImageCreate(rgb->width, rgb->height, rgb->depth,
                                    AVIF_PIXEL_FORMAT_YUV420);
  printf("AVIF image: %dx%d, depth %d, pixelFormat %d\n", avif->width,
         avif->height, avif->depth, avif->yuvFormat);
  avif->yuvRange = AVIF_RANGE_FULL;
  fflush(stdout);

  // avifImageAllocatePlanes(avif, AVIF_PLANES_YUV);

  avifRGBImage rgbInput;
  avifRGBImageSetDefaults(&rgbInput, avif);
  rgbInput.format = rgb->format;
  // rgbInput.format = AVIF_RGB_FORMAT_RGB;     // not AUTO
  rgbInput.ignoreAlpha = AVIF_TRUE; // ensure no alpha
  // rgbInput.depth = rgb->depth;
  rgbInput.pixels = rgb->pixels;
  rgbInput.rowBytes = rgb->rowBytes;

  printf("RGB image: %dx%d, depth %d, pixelFormat %d\n", rgbInput.width,
         rgbInput.height, rgbInput.depth, rgbInput.format);

  printf("rgb->pixels: %p\n", rgb->pixels);
  printf("First pixel RGB: R=%d G=%d B=%d\n", rgbInput.pixels[0],
         rgbInput.pixels[1], rgbInput.pixels[2]);
  fflush(stdout);

  printf("rgbInput.format: %d\n", rgbInput.format);
  printf("rgbInput.depth: %d\n", rgbInput.depth);
  printf("rgbInput.rowBytes: %d\n", rgbInput.rowBytes);
  printf("rgbInput.pixels[0]: 0x%02X\n", rgbInput.pixels[0]);
  fflush(stdout);

  avifImageRGBToYUV(avif, &rgbInput);

  printf("YUV Plane 0: %p\n", avif->yuvPlanes[0]);
  printf("YUV Plane 1: %p\n", avif->yuvPlanes[1]);
  printf("YUV Plane 2: %p\n", avif->yuvPlanes[2]);
  fflush(stdout);

  avifEncoder *encoder = avifEncoderCreate();
  encoder->maxThreads = 1;
  encoder->speed = 6;
  encoder->quality = 60;

  avifResult result = avifEncoderWrite(encoder, avif, output);

  printf("avifEncoderWrite result: %s (%d)\n", avifResultToString(result),
         result);
  fflush(stdout);

  printf("Encoding result: %d\n", result);
  printf("Output size: %zu\n", output->size);
  fflush(stdout);

  avifEncoderDestroy(encoder);
  avifImageDestroy(avif);

  printf("AvifOkay: %d", result == AVIF_RESULT_OK ? 1 : 0);
  fflush(stdout);

  return result == AVIF_RESULT_OK ? 0 : 1;
}

///////// * /////////
// **** JPEG **** //
///////// * /////////

// VALIDATION
EMSCRIPTEN_KEEPALIVE
bool is_jpeg(const uint8_t *buffer, size_t length) {
  return length >= 4 && buffer[0] == 0xFF && buffer[1] == 0xD8 &&  // SOI
         buffer[length - 2] == 0xFF && buffer[length - 1] == 0xD9; // EOI

  // TODO check these
  // 1. walk through each segment (marker starts with 0xFF)
  // 2. handle segment lengths
  // 3. skip or parse APPO/APP1 segments
  // 4. ensure there's at least one SOS and one EOI marker
  // 5. Validate no bad lengths or crashes
}

// FIND THE EXIF
EMSCRIPTEN_KEEPALIVE
void find_exif_jpeg(const uint8_t *buffer, size_t length, char **output) {

  if (!is_jpeg(buffer, length))
    return;

  const char *json = parse_jpeg(buffer, length);
  size_t len = strlen(json);
  *output = malloc(len + 1);
  memcpy(*output, json, len + 1); // +1 for null terminator

  return;
}

// DECODE THE JPEG
EMSCRIPTEN_KEEPALIVE
int decode_jpeg(const uint8_t *jpegData, size_t jpegSize, avifRGBImage *rgb) {

  struct jpeg_decompress_struct cinfo;
  struct jpeg_error_mgr jerr;

  JSAMPARRAY buffer;
  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_decompress(&cinfo);

  jpeg_mem_src(&cinfo, jpegData, jpegSize);
  jpeg_read_header(&cinfo, TRUE);
  jpeg_start_decompress(&cinfo);

  if (cinfo.output_components != 3) {
    fprintf(stderr,
            "Unsupported JPEG format: expected 3 components (RGB), got %d\n",
            cinfo.output_components);
    return -1;
  }

  int width = cinfo.output_width;
  int height = cinfo.output_height;
  int channels = cinfo.output_components;

  printf("%dx%d\n", cinfo.output_width, cinfo.output_height);

  rgb->width = width;
  rgb->height = height;
  rgb->depth = 8;
  rgb->format = AVIF_RGB_FORMAT_RGB;
  avifRGBImageAllocatePixels(rgb);

  while (cinfo.output_scanline < height) {
    uint8_t *row = rgb->pixels + cinfo.output_scanline * rgb->rowBytes;
    jpeg_read_scanlines(&cinfo, &row, 1);
  }

  printf("row Bytes: %d", rgb->rowBytes);
  fflush(stdout);

  jpeg_finish_decompress(&cinfo);
  jpeg_destroy_decompress(&cinfo);

  printf("jpegData%d", jpegData[0]);
  printf("First pixel RGB: R=%d G=%d B=%d\n", rgb->pixels[0], rgb->pixels[1],
         rgb->pixels[2]);
  fflush(stdout);

  return 0;
}

// CONVERT THE JPEG
EMSCRIPTEN_KEEPALIVE
uint8_t *convert_jpeg_to_avif(uint8_t *jpegBuffer, size_t jpegSize,
                              size_t *avifSizeOut) {
  printf("encoding to avif");
  fflush(stdout);

  avifRGBImage rgb;
  memset(&rgb, 0, sizeof(rgb));
  decode_jpeg(jpegBuffer, jpegSize, &rgb);

  avifRWData avifOutput = AVIF_DATA_EMPTY;
  bool success = encodeToAVIF(&rgb, &avifOutput);

  printf("AvifOkay: %d\n", success);
  fflush(stdout);

  avifRGBImageFreePixels(&rgb);

  if (success) {
    printf("success %d\n", success);
    return NULL;
  }

  printf("avif Size %zu\n", avifOutput.size);
  fflush(stdout);

  *avifSizeOut = avifOutput.size;
  return avifOutput.data;
}

// //////// * ////////
// // **** PNG **** //
// //////// * ////////
// EMSCRIPTEN_KEEPALIVE
// bool is_png(const uint8_t* buffer, size_t length) {
//     return length >= 8 &&
//         buffer[0] == 0x89 && // corruption check
//         buffer[1] == 0x50 && // 'p'
//         buffer[2] == 0x4E && // 'n'
//         buffer[3] == 0x47 && // 'g'
//         buffer[4] == 0x0D && // carriage return
//         buffer[5] == 0x0A && // Line feed
//         buffer[6] == 0x1A && // Truncate detection
//         buffer[7] == 0x0A; // Line feed

//         // Todo check these
//         // 1. file not corrupt
//         // 2. internal chunks are valid
//         // 3. contains expected structure
//         // 4. no malicious or malformed chunk (intended to crash a parser)
// }

EMSCRIPTEN_KEEPALIVE
bool is_valid_avif_or_heic(const uint8_t *buffer, size_t length) {
  if (length < 16)
    return false;

  uint32_t box_size =
      (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | (buffer[3]);

  if (box_size < 20 || box_size > length)
    return false;

  // Check 'ftyp'
  if (buffer[4] != 'f' || buffer[5] != 't' || buffer[6] != 'y' ||
      buffer[7] != 'p') {
    return false;
  }

  // Check Major brand: 'avif' or 'heic'
  bool is_avif = buffer[8] == 'a' && buffer[9] == 'v' && buffer[10] == 'i' &&
                 buffer[11] == 'f';

  bool is_heic = buffer[8] == 'h' && buffer[9] == 'e' && buffer[10] == 'i' &&
                 buffer[11] == 'c';

  return is_avif || is_heic;

  // Todo check these
  // 1. parse the box hierarchy
  // 2 find and confirm boxes
}

// Detects what format an image is
// ImageFormat detect_format(const uint8_t* buffer, size_t length) {
//     if (is_jpeg(buffer, length)) return FORMAT_JPEG;
//     if (is_png(buffer, length)) return FORMAT_PNG;
//     if (is_valid_avif_or_heic(buffer, length)) return FORMAT_AVIF;
// }

void *malloc_wrapper(int size) { return malloc(size); }

void free_wrapper(void *ptr) { free(ptr); }