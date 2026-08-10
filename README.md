# Rescue Files

## If your computer will not start

Do not repair permissions or change anything on the old drive. This tool copies your personal files from it without changing or deleting anything there.

You need:

- A working Windows computer where you can sign in as an administrator.
- The drive removed from the computer that will not start, connected by a USB drive adapter or enclosure.
- A different NTFS-formatted drive with enough empty space for the rescued files.

If the old drive makes clicking or grinding sounds, repeatedly disconnects, or disappears from File Explorer, stop. Continuing can make a damaged drive worse. Ask a computer repair or data-recovery professional for help.

## Copy your files

1. Download this whole folder onto the working Windows computer. Keep `Rescue Files.bat`, `Rescue-Files.ps1`, and `RescueFiles.Core.psm1` together.
2. Connect the old drive and the drive where you want the rescued files saved.
3. Double-click **Rescue Files.bat**.
4. When Windows asks whether to allow changes, choose **Yes**. The tool needs this permission to read files whose old Windows permissions no longer work.
5. Follow the numbered choices on screen. The old drive is usually the one that is not marked as this computer's drive.
6. Check the source, destination, file count, and space shown before answering **Y** to start.
7. Leave both drives connected until the tool says it has finished.
8. Open the `RESCUED - name` folder on the destination drive and check your important documents and photos.

The copy may take hours. The computer is kept awake while it runs, and its previous sleep setting is restored afterward.

## If the copy stops

Run **Rescue Files.bat** again and choose the same person and destination. Files already copied are skipped, so the rescue continues without starting over. Closing the window does not delete or damage files on the old drive.

Never disconnect either drive while its activity light is flashing. If Windows says a drive is busy, shut down the working computer before unplugging it.

## What is copied

The tool includes the usual Desktop, Documents, Downloads, Pictures, Music, and Videos folders. It skips:

- `AppData`, which mainly contains program settings, browser data, and temporary files.
- `.cache`, which contains temporary data.
- `OneDrive`, because those files should normally be recovered by signing in to OneDrive again.
- Windows junctions, which can lead back into folders already being copied.

The destination must use the NTFS format. To check a drive, right-click it in File Explorer, choose **Properties**, and look beside **File system**. Formatting a drive erases it, so do not format a drive that contains anything you need.

## Understanding the result

An all-successful result is shown in green. The tool also saves a text log beside the rescued folder on the destination drive. Nothing, including the log, is ever written to the old source drive.

If a few failures are all in one folder, they are often damaged or disposable cache files. Check the files you care about. If failures appear across several folders, the old drive may be failing. Stop using it and seek professional help.

## Safety guarantees

Rescue Files uses Windows Robocopy backup mode to read through permissions left by the old Windows installation. It does not take ownership or rewrite permissions. Its copy command never uses mirror, move, or purge options, and it refuses to use the source volume as the destination.

## License

Rescue Files is available under the [MIT License](LICENSE).
