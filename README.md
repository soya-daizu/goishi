# Goishi

An experimental QR Code locator/extractor library written purely in Crystal. It works on top of [Goban](https://github.com/soya-daizu/goban), a QR Code encoder/decoder library, and takes a matrix of each source image pixel to locate and extract QR Code symbols in the image. 

The library is already capable of locating/extracting regular QR Code symbols, however the implementation is not complete and may fail with some edge cases. The goal is to finish the implementation for regular QR Code and then expand it to support other QR Code types such as Micro QR and rMQR Code.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     goishi:
       github: soya-daizu/goishi
   ```

2. Run `shards install`

## Usage

See `examples/extract_test.cr` for the usage with [stumpy\_png](https://github.com/stumpycr/stumpy_png) to read, locate/extract, and decode QR Codes in the image.

## Contributing

1. Fork it (<https://github.com/your-github-user/goishi/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [soya_daizu](https://github.com/soya-daizu) - creator and maintainer
