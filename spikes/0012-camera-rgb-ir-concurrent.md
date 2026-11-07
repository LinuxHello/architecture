---
type: spike
subject: Camera streams RGB and IR at the same time
artifact: spike
status: answered
owner: "@atterdag"
concepts: [camera, v4l2, ir-camera, face, enrolment]
tags: [spike, m0]
sources: []
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/12
---

# Spike: Camera streams RGB and IR at the same time

## Question

Can a typical Windows Hello-class IR camera stream its RGB and IR sensors at the same time on Linux?

## Time box

Proposed: 2 working days. Stop at the time box and record what is known.

## Method

Enumerate V4L2 devices and formats on at least two IR camera models; try concurrent capture; record kernel and driver versions.

Run on one model only, a Logitech BRIO 4K on a USB 3 port (5000M hub), kernel 7.0.0-43-generic, uvcvideo, `v4l2-ctl` 1.32.0, Ubuntu 26.04. Frames were captured with `v4l2-ctl --stream-mmap --stream-to=/dev/null` and discarded; nothing was saved. **Tested**, all commands below. **Untested:** a second camera model, which the method asks for, and any capture through a library such as OpenCV or GStreamer.

## Blocks

The face enrolment wizard shows the RGB feed while Howdy captures IR. Blocks the face enrolment wizard design.

## Evidence

**Device layout (tested).** One USB device, four nodes: `/dev/video0` RGB (YUYV and MJPG, 160x120 up to 1080p), `/dev/video2` IR (`GREY` 8-bit, 340x340 only), `/dev/video1` and `/dev/video3` metadata. RGB and IR are separate V4L2 nodes of the same device.

**One stream at a time (tested).** RGB 640x480 YUYV ran at 26 to 30 fps. IR 340x340 GREY ran at 25 to 30 fps. Both worked again after every failure below.

**Both at once (tested).** Counts are runs, not frames.

| Start order | RGB mode | Result |
| :-- | :-- | :-- |
| Both started together (4 runs) | 640x480 YUYV | Never both: IR worked and RGB hung (timeout) twice; RGB worked and IR failed `VIDIOC_STREAMON` with Input/output error twice |
| Both together (1 run) | 1280x720 MJPG | RGB 30 fps; IR `VIDIOC_STREAMON` Input/output error |
| RGB first, IR 1 s later (2 runs) | 320x240 and 640x480 YUYV | Both streamed; IR 26 to 28 fps; RGB started slowly (0.7 fps in the first seconds) and recovered to about 11 to 12 fps average over the run |
| IR first, RGB 1 s later | 320x240 YUYV | Both streamed; RGB 28 fps, IR 24 fps |
| IR first, RGB 1 s later | 640x480 YUYV | Both hung (timeout) |
| IR first, RGB 1 s later | 1280x720 MJPG | Both failed `VIDIOC_DQBUF` (Invalid argument) |

## Answer

**Partly.** The BRIO's RGB and IR sensors are separate V4L2 nodes, and both can stream at the same time, but starting them is unreliable on this camera: no run that started both together worked, and with a one-second gap it depended on the order and the RGB mode. The device recovered each time.

What it means for the design, from this one model:

- The enrolment wizard cannot assume it can open the RGB preview and the IR capture independently. It needs one component that owns both streams, opens them in a fixed order with a retry, and tells the user when it falls back to showing no live RGB preview.
- A low RGB mode (320x240 YUYV) opened after the IR stream was the combination that worked cleanly. Treat that as a starting point, not a guarantee.
- The cause is not established. USB bandwidth is unlikely on a 5000M port; the camera's firmware or the uvcvideo driver arbitrating the two streams is more likely. No kernel log was read.

Not covered: a second camera model, other USB ports or hubs, a capture library instead of `v4l2-ctl`, and the IR emitter (the frames were not looked at). Re-run on at least one more IR camera before the wizard design relies on this.
