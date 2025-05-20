# \[Sample Only] Shimmer

**Note: This will not be professionally developed or distributed on the App Store. It is only public for reference purposes, and so that others may fork it for themselves if desired (no attribution required).**

Demo below (very hard to see the emission blink in this lighting, may or may not re-record):

https://github.com/user-attachments/assets/b7953273-f210-4927-8f61-7084804cbd4e

## Usage Notes

This application expects the VRChat avatar to have a `HeartRate` avatar parameter (float), and to have enabled OSC. VRChat will open an endpoint at `/avatars/parameters/HeartRate` that OSC data will be sent to.

That parameter can then drive animations however you wish. One way to use this is to create an Animation Clip with Loop Time disabled, with two keyframes: one representing the state at `HeartRate=0.0`, and the
other representing the state at `HeartRate=1.0`. Add the Animation Clip as an Animator State, and connect `HeartRate` to the Animator State's Motion Time parameter. Set the Animation Speed to 0 to avoid
playback outside of the parameter value.
