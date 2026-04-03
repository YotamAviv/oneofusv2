let currentIndex = -1;
const cues = document.querySelectorAll(".cue");

function setActive(index) {
  if (index < 0) index = 0;
  if (index >= cues.length) index = cues.length - 1;

  currentIndex = index;

  cues.forEach((cue, i) => {
    cue.classList.remove("active", "near");

    if (i === index) {
      cue.classList.add("active");
      cue.scrollIntoView({ behavior: "smooth", block: "center" });
    } else if (Math.abs(i - index) <= 2) {
      cue.classList.add("near");
    }
  });
}

document.addEventListener("keydown", (e) => {
  if (e.code === "Space" || e.code === "ArrowRight" || e.code === "ArrowDown") {
    e.preventDefault();
    setActive(currentIndex + 1);
  } else if (e.code === "ArrowLeft" || e.code === "ArrowUp") {
    e.preventDefault();
    setActive(currentIndex - 1);
  }
});

cues.forEach((cue, i) => {
  cue.addEventListener("click", () => setActive(i));
});
