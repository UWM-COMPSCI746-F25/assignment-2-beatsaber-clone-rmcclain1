[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-22041afd0340ce965d47ae6ef1cefeee28c7c493a6346c4f15d667ab976d596c.svg)](https://classroom.github.com/a/aJFhgZsk)
# Assignment 2: Making Beat Saber in Godot

[Beat Saber](https://beatsaber.com/) is widely considered to be one of the best and most successful virtual reality games. There is a [free demo](https://www.meta.com/experiences/beat-saber-demo/1758986534231171/?srsltid=AfmBOooDuQ3aC4om9Wwq6gpucpNpqOjh1al92yRuZYBNlaGS2hlGMLII) available for the Meta Quest 2, which you should be able to find in the official store app. Before beginning this assignment, I suggest that you download this demo or watch some videos on YouTube to familiarize yourself with the gameplay.

In this assignment, you will be implementing Beat Saber's core mechanics. You can use Godot's built-in 3D objects (e.g., boxes) for this assignment, and you do not need to import custom meshes. If you want to make your game more interesting, you are also free to import additional assets or modify the appearance of the scene. Creativity is encouraged! However, note that your grade will be based on the interaction functionality, not the artistic quality of the game.

## Submission Information

You should fill out this information before submitting your assignment.  Make sure to document the name and source of any third party assets such as 3D models, textures, or any other content used that was not solely written by you.  Include sufficient detail for the instructor or TA to easily find them, such as a download link.

Name: 

UWM Email:

Third Party Assets:

## Getting Started

Clone the assignment using GitHub Classroom. Links to some resources will be available on the Canvas assignment page.

## Rubric

Graded out of 20 points. 

1. Construct laser swords for each controller by having a line renderer and a ColliderShape extend along the controller's negative z direction (see the laser pointer lecture). Pressing the primary button on each controller ("A" for the right controller and "X" for the left controller) should toggler the laser's visibility. Laser swords that are "off" should not interact with any other objects. The laser should be approximately 1 meter long. (3)
1. Make a single cube that starts at the far end of the virtual environment (at least 10 meters away) and moves towards the user's start position.  Adjust the size and velocity so that it provides an appropriate challenge for the user who will try to swing at it. (1)
1. When the user hits a cube with a laser sword, the cube should be destroyed. (2)
1. Write a function that connects to OpenXR's "On Pose Recentered" signal ([https://docs.godotengine.org/en/stable/tutorials/xr/a_better_xr_start_script.html#on-pose-recentered](https://docs.godotengine.org/en/stable/tutorials/xr/a_better_xr_start_script.html#on-pose-recentered)). When the user presses and holds the "Oculus" button on the right controller, their virtual position and orientation should be altered such that they are centered to your flying cube and they are facing it. (2)
1. Play a sound when the cube is destroyed. There are plenty of websites for free sound effects.  You should find one that you like and import it into your project. (2)
1. Create a `CubeSpawner` node/script that creates new cubes at random time intervals between 0.5 and 2.0 seconds.  You can feel free adjust these time thresholds to reach an appropriate difficulty.  The cubes should also start at the far end of the environment (>10 meters away from the user), fly towards the user, and should be destroyed when hit by a laser sword. *Hint: you can create a scene instance for the cube and then `instantiate` to instantiate copies of it ([Nodes and scene instances](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html)).* (3)
1. The exact X and Y positions of the spawned cubes should be chosen randomly, but should always be within reach of the user's swords when standing at the start position. (2)
1. If a cube goes past the user, it should also be destroyed, but no sound effect should be played.  We don't want to end up with infinite cubes that would slow down the Quest! (2)
1. Create a "left" and "right" color for the laser swords (you might use blue for right and red for left, for example). Randomly assign the same color to each cube created by the `CubeSpawner`. Cubes should only be destroyed if they are cut by the laser sword with the same color. That is, blue cubes should only be destroyed by the blue sword, and red cubes should only be destroyed by the red sword. You are free to pick whatever two colors you want (provided the are sufficiently different). (3)

**Bonus Challenges (max 3 points, only available if all 20 points are already awarded):** 

1. Transform your project into a real rhythm game!  Find a music track that you like and add it as an audio source in the scene.  Then, modify your `CubeSpawner` so that instead of spawning cubes randomly, the user will need to hit them according to the beat of the music.  You will need to store the time for spawning each cube in a data structure that the `CubeSpawner` can iterate through.  To accomplish this, you may want to play the music track in an external application such as [Audacity](https://www.audacityteam.org/) and make a list of times for each beat.  When you start playing the music, make sure to insert a delay to account for the time for the cubes to travel to the player.  You do not need to do this for the entire song; approximately 20-30 seconds of gameplay will be sufficient for bonus credit. (2)

1. Add a texture to each of the spawned cubes that indicates a particular direction (something like an arrow). Only destroy the cube if the sword swing came from that direction. When a cube is spawned, it should be rotated so that the direction of the arrow is either up, down, left, or right, selected randomly. (2)

1. Instead of the cube simply disapearing when it is destroyed, have it "decompose" into several (>4) smaller blocks that blow apart, and then disapear. The smaller blocks should not be interactable with the laser swords. (1) 

Make sure to document all third party assets in your readme file. ***Be aware that points will be deducted for using third party assets that are not properly documented.***

## Submission

You will need to check out and submit the project through GitHub classroom. Do not remove the `.gitignore` or `README.md` files.

Instead of having the APK be uploaded to GitHub, you will submit it through Canvas. Make sure to commit and push your code to GitHub and to submit the APK on Canvas by the deadline.

Please test that your submission meets these requirements.  For example, after you check in your final version of the assignment to GitHub, check it out again to a new directory and make sure everything opens and runs correctly.  You can also test your APK file by installing it manually using [SideQuest](https://sidequestvr.com/).

## Acknowledgements

This assignment is a modified version of an assignment from a class taught by Professor Evan Suma Rosenberg at the University of Minnesota.

