import timeit

from scripts.quality import score_content


def run_benchmark() -> None:
    """Run a performance benchmark for the score_content function."""
    # 8000 character string
    base_text = "This is a sample text for benchmarking. " * 100
    noisy_text = "cookie subscribe javascript log in sign up " * 20
    content = (base_text + noisy_text)[:8000]

    links = ["https://example.com/1", "https://example.com/2"]

    # Run 1000 times
    number = 1000
    timer = timeit.Timer(lambda: score_content(content, links))

    result = timer.timeit(number=number)
    avg_time = (result / number) * 1000  # in ms

    print(f"Benchmark: score_content called {number} times")
    print(f"Average time per call: {avg_time:.4f} ms")
    print(f"Total time: {result:.4f} s")


if __name__ == "__main__":
    run_benchmark()
