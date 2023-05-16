# invisibile

This repository is designed to convert GIFs to MOVs while respecting transparency,
and to illustrate the use of HEVCs with transparency in SceneKit for Augmented Reality apps.

## Details

The repository is divided in two parts:

### 1. Converter from GIF to MOV

`GIFToMOVConverter` converts GIFs to MOVs, utilizing the HEVC codec with Transparency.
This ensures that the transparency present in the GIF layers is respected.

This is especially useful when you want to layer multiple GIFs in 3D on top of each other and
have them also be see-through, to save memory.

But it can also be used in any other situation where you need to save memory but stil display
GIFs. For example, when saving GIFs to a database to dispay them later on other devices: converting
them to HEVC files will save time in uploading and downloading and provide a much better experience.
See this article for more details: [Replace animated GIFs with video for faster page loads](https://web.dev/replace-gifs-with-videos).

If you just used the GIF layers directly, displaying them as textures in SceneKit or RealityKit,
you would quickly run out of memory on iPhone.

### 2. Demo of showing the animated GIF in 3D using SceneKit

As explained above, one of the prime uses of this is to show animated 2D GIFs in 3D apps,
using SceneKit (or RealityKit).

The `VideoSpriteKitSceneNode` shows how to use SpriteKit and SceneKit to show a 3D node of a
2D animated GIF. Thanks to the memory savings from using MOVs, you can have > 10 GIFs shown
this way in a single app.

## Credits

* App icon: Eye by [Daniel Tacho](https://thenounproject.com/icon/eye-4786602/) from Noun Project.
  
## References

* <https://developer.apple.com/documentation/avfoundation/media_playback/using_hevc_video_with_alpha>

## Authors

[@snowzurfer](https://github.com/snowzurfer) - [Alberto Taiuti](https://twitter.com/albtaiuti)

## License

See LICENSE
