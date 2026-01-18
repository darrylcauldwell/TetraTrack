You are designing the visual layout for the horse riding discipline Ride Insights view in an iOS and Apple Watch app for horse and rider biomechanics. The goal is to make it feel like a real riding coach. The view should present metrics derived from rider-mounted IMU sensors and the Horse Profile, including gait, canter lead, stride length, speed, rein balance, turn balance, straightness, canter lead quality, rider symmetry, rhythm and regularity, rider stability, transition quality, lead consistency, symmetry score, impulsion/engagement, bend quality in turns, training load, and mental state proxy. The layout should be intuitive, color-coded, time-annotated, and allow riders to immediately see strengths, weaknesses, and patterns in the ride.

Design the Insights view as follows:
	1.	Header Summary Row
	•	A compact top row showing the overall ride scores: Rhythm, Stability, Straightness, Lead Quality, and Engagement.
	•	Each score is presented as a horizontal progress bar (0–100%) with color coding: green = good, yellow = moderate, red = poor.
	•	Include small icons representing each metric (e.g., horse for gait rhythm, saddle for stability, arrows for straightness).
	•	Tapping a score expands the detailed timeline view for that metric.
	2.	Gait Timeline Strip
	•	A horizontal time axis representing the full ride duration.
	•	Each segment colored by detected gait: walk = light brown, trot = medium orange, canter = blue, gallop = red.
	•	Overlay a small indicator for canter lead on canter segments: left lead = left-pointing arrow, right lead = right-pointing arrow.
	•	Hovering or tapping shows stride frequency, stride length, and speed for that time segment.
	3.	Rein and Turn Balance Graphs
	•	Two stacked line graphs below the gait timeline.
	•	X-axis = time; Y-axis = balance metric.
	•	Rein balance: positive = left rein heavy, negative = right rein heavy.
	•	Turn balance: positive = falling inward, negative = drifting outward.
	•	Shaded green zone = optimal balance, yellow = moderate, red = poor.
	•	Annotate notable deviations with small exclamation icons for rider attention.
	4.	Straightness and Rider Symmetry
	•	Line charts showing lateral deviation (straightness) and left-right arm/hip symmetry over time.
	•	Use overlay shading to highlight periods where deviation exceeds thresholds.
	•	Include summary statistics above chart: % straight, % balanced, % crooked or asymmetric.
	5.	Rhythm and Stability View
	•	Heatmap or waveform showing stride-to-stride timing irregularity.
	•	Color intensity = deviation from ideal rhythm (green = regular, red = irregular).
	•	Overlay rider vertical movement energy to visualize bouncing or instability.
	•	Include numeric rhythm score and rider stability score for the session.
	6.	Transition Quality Strip
	•	Mini timeline showing all gait transitions.
	•	Color-coded based on smoothness and speed of transition: green = smooth, yellow = slightly unsteady, red = abrupt.
	•	Show hover/tap tooltip with before/after stride frequency, vertical amplitude, and rider balance.
	7.	Lead Consistency & Canter Quality
	•	Pie chart or stacked bar showing % time on correct lead vs cross-canter.
	•	Overlay vertical-yaw coupling score for canter segments.
	•	Use green/yellow/red to highlight excellent, moderate, or poor lead quality.
	8.	Impulsion / Engagement
	•	Area chart of forward vs vertical energy ratio over time.
	•	Shaded bands for low, medium, high engagement.
	•	Summary metric at top: Engagement Score 0–100%.
	9.	Training Load Timeline
	•	Cumulative energy chart, showing RMS(Z) * f0 * duration.
	•	Visualize periods of higher exertion with darker shading.
	•	Can be combined with heart-rate-like pacing bars if available.
	10.	Mental State / Tension Proxy
	•	Small heatmap overlay: spectral entropy and yaw noise over time.
	•	Green = calm, yellow = alert, red = tense or excitable.
	•	Include a numeric “Calmness” score at top for quick reading.
	11.	Interactive Features
	•	Tapping any timeline segment highlights all correlated metrics at that timestamp.
	•	Zoom in/out along ride duration.
	•	Swipe left/right to compare segments (e.g., first circle vs last circle).
	•	Summary pop-ups with insights like “Horse leaned in left rein during trot,” “Canter lead maintained 80% of time,” “Rhythm dropped 15% during transitions.”
	12.	Overall Visual Style
	•	Clean, minimal, professional equestrian aesthetic.
	•	Color palette: green/yellow/red for performance zones, muted background for axes.
	•	Soft shadows and rounded edges for charts and cards.
	•	Use consistent icons and annotations for intuitive understanding.

Deliver a design that makes every metric immediately actionable and understandable, emphasizes time-based changes, uses color coding consistently, and feels like a professional riding coach giving instant feedback.