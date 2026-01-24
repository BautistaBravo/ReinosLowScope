from PIL import Image, ImageDraw
import os

def create_sprite(filename, color, size=(64, 64)):
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Draw a colored rectangle
    draw.rectangle([4, 4, size[0]-4, size[1]-4], fill=color, outline="black")
    path = os.path.join("sprites", filename)
    img.save(path)
    print(f"Created {path}")

def main():
    if not os.path.exists("sprites"):
        os.makedirs("sprites")

    create_sprite("slime.png", "lime")
    create_sprite("goblin.png", "darkgreen")
    create_sprite("orc.png", "darkgray")
    create_sprite("skeleton.png", "white")
    create_sprite("dragon.png", "red", size=(128, 128))

if __name__ == "__main__":
    main()
