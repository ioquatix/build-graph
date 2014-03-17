
#include <iostream>
#include <vector>

std::vector<int> get_numbers() {
	return {10, 20, 30, 40, 50, 60, 80};
}

int main (int argc, char ** argv)
{
	auto numbers = get_numbers();
	std::sort(numbers.begin(), numbers.end());
	
	for (auto & number : numbers)
		std::cerr << number << "?" << std::endl;
	
	return 0;
}
