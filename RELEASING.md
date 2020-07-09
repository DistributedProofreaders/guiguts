# Cutting a release

This provides instructions for publishing a new guiguts release on
Github.

1. Update the version. This needs to happen in two places:
	* `Makefile`
	* `guiguts.pl`

2. Update the `CHANGELOG.md`

3. Commit the version update changes and tag the release
   (ie: `git tag r<version>`) and push it up to github

4. From a Linux or MacOS system, or a Windows system with MinGW installed,
   confirm that you are working from a clean git checkout. Then build the
   three releases using `make` or `make all` or
   ```
   make win
   make mac
   make generic
   ```
   This creates three .zip files, one for each platform.

   Be certain to keep the format `guiguts-platform-1.0.0.zip`
   (platform and version number will vary) in order for
   the update mechanism to work correctly. Do not include
   `settings.rc` or `header.txt` as these may have been modified
   by the user and will be created if they do not exist.
   The `Makefile` takes care of this.

5. Publish the release on Github.com
	1. Log into [github.com](https://github.com)
	2. Access the [guiguts releases](https://github.com/DistributedProofreaders/guiguts/releases)
	3. Select *Draft a new release*
	4. Specify the tag (ie: `r<version>`)
	5. Specify the title (ie: `<version>`)
	6. Describe the release - can be a copy/paste of the `CHANGELOG.md`
	   details for the release
	7. Attach the .zip files
	8. Publish release
