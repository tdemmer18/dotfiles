import random

def generate_random_numbers():
  """Generates and prints 1000 random numbers between 1 and 500000."""
  for _ in range(1000):
    print(random.randint(1, 500000))

if __name__ == "__main__":
  generate_random_numbers()
