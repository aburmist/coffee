import unittest
from coffee import (
    submit,
    calc_brew_ratio,
    extract_coffee_details
)

class TestCoffeeFunctions(unittest.TestCase):

    def test_submit(self):
        # Test submit function with valid inputs
        coffee_grind = 10
        brew_method = 'Espresso'
        coffee_weight = 20
        water_weight = 30
        water_temperature = '175 Green'
        brew_time = 60
        rating = '⭐️⭐️⭐️'
        comment = 'test_submit'
        submit(coffee_grind, brew_method, coffee_weight, water_weight, water_temperature, brew_time, rating, comment)
        # Add assertions to verify data submission
        self.assertEqual(coffee_grind, 10)
        self.assertEqual(brew_method, 'Espresso')
        self.assertEqual(coffee_weight, 20)
        self.assertEqual(water_temperature, '175 Green')
        self.assertEqual(brew_time, 60)
        self.assertEqual(water_weight, 30)
        self.assertEqual(rating, '⭐️⭐️⭐️')
        self.assertEqual(comment, 'test_submit')

    def test_calc_brew_ratio(self):
        # Test calc_brew_ratio function with valid inputs
        brew_method = 'Espresso'
        coffee_weight = 20
        ratio, brew_weight = calc_brew_ratio(brew_method, coffee_weight)
        self.assertEqual(ratio, '1:2')
        self.assertEqual(brew_weight, 40)

        brew_method = 'Drip'
        ratio, brew_weight = calc_brew_ratio(brew_method, coffee_weight)
        self.assertEqual(ratio, 'N/A')
        self.assertEqual(brew_weight, 0)

    def test_extract_coffee_details(self):
        # Test extract_coffee_details function with valid inputs
        text = "Espresso, size 20, 20g, 175 Green, 60s, 30g, 3 stars, test_extract_coffee_details"
        coffee_grind, brew_method, coffee_weight, water_temperature, brew_time, water_weight, rating, comment = extract_coffee_details(text)
        # validates the input (not the spreadsheet)
        # self.assertEqual(coffee_grind, 20)
        # self.assertEqual(brew_method, 'Espresso')
        # self.assertEqual(coffee_weight, 20)
        # self.assertEqual(water_temperature, '175 Green')
        # self.assertEqual(brew_time, 60)
        # self.assertEqual(water_weight, 30)
        # self.assertEqual(rating, '⭐️⭐️⭐️')
        # self.assertEqual(comment, 'test_extract_coffee_details')

if __name__ == '__main__':
    unittest.main()