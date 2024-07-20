import pandas as pd
import streamlit as st
from streamlit_gsheets import GSheetsConnection
import datetime

st.set_page_config(page_title="Coffee Taster ☕", page_icon="☕")

# Create a connection object
conn = st.connection("gsheets", type=GSheetsConnection)

def submit(coffee_grind, brew_method,coffee_weight, water_weight, water_temperature, brew_time, rating, comment):
    df = conn.read(
        ttl=0,
        usecols=['coffee_weight', 'coffee_grind', 'water_weight', 'water_temperature', 'brew_time', 'brew_method', 'rating', 'comment', 'date']
    )
    df = df.dropna(how='all')

    # Define variables
    current_date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    new_record = {
        "coffee_weight": [coffee_weight],
        "coffee_grind": [coffee_grind],
        "water_weight": [water_weight],
        "water_temperature": [water_temperature],
        "brew_time": [brew_time],
        "brew_method": [brew_method],
        "rating": [rating],
        "comment": [comment],
        "date": [current_date]
    }
    df = pd.concat([df, pd.DataFrame(new_record)], ignore_index=True)
    df = conn.update(
        worksheet="data",
        data=df
    )

def calc_brew_ratio(brew_method, coffee_weight):
    """
    """
    if brew_method == 'Espresso':
        ratio = '1:2'
        return ratio, coffee_weight * 2
    elif brew_method == 'Aeropress':
        ratio = '1:12.5'
        return ratio, coffee_weight * 12.5
    elif brew_method == 'Pour Over':
        ratio = '1:17'
        return ratio, coffee_weight * 17
    elif brew_method == 'Clever':
        ratio = '1:15'
        return ratio, coffee_weight * 15
    elif brew_method == 'French Press':
        ratio = '1:15'
        return ratio, coffee_weight * 15
    elif brew_method == 'Moka':
        ratio = '1:7'
        return ratio, coffee_weight * 7
    elif brew_method == 'Drip':
        ratio = 'N/A'
        return ratio, 0
    else:
        return 'N/A', 0

def main():
    st.title('Coffee Taster ☕')

    st.subheader('**Record your coffee**')

    with st.form(key='input_form'):
        col1, col2 = st.columns(2)
        with col1:
            brew_method = st.selectbox('Brew method', ['Espresso', 'Aeropress', 'Pour Over', 'Clever', 'French Press', 'Moka', 'Drip'])
            water_temperature = st.selectbox('Temperature', ['175 Green', '185 White', '190 Oolong', '200 FrenchPress', 'Boil'])
        with col2:
            coffee_weight = st.number_input('Coffee weight (g)')
            coffee_grind = st.number_input('Grind size', max_value=40, placeholder='1-40')
        captured = st.form_submit_button('Get Brew Ratio')

    if captured:
        ratio, brew_weight = calc_brew_ratio(brew_method, coffee_weight)
        st.write(f'Ideal Brew Ratio for {brew_method} is {ratio} and should weight {int(brew_weight)} grams.')

    with st.form(key='my_form'):
        col1, col2 = st.columns(2)
        with col1:
            brew_time = st.number_input('Brew time (s)', step=1)
            water_weight = st.number_input('Water weight (g)', step=10)
        with col2:
            rating = st.selectbox('Rating', ['⭐️', '⭐️⭐️', '⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️⭐️'])
            comment = st.text_input("Comment", help="Coffee brand, tasting notes, etc.", placeholder="Tasting notes...")
        submitted = st.form_submit_button('Review')
   
    if submitted:
        submit(coffee_grind, brew_method,coffee_weight, water_weight, water_temperature, brew_time, rating, comment)
        st.markdown(f'''
            ☕ You have tasted a coffee with the following characteristics:
            - Weight (g): `{coffee_weight}`
            - Water (g): `{water_weight}`
            - Time (s): `{brew_time}`
            - Temperature: `{water_temperature}`
            - Rating: `{rating}`
            - Grind: `{coffee_grind}`
            - Method: `{brew_method}`
            - Comment: `{comment}`
            ''')
        # st.balloons()
    else:
        st.write('☝️ Record coffee!')

if __name__ == '__main__':
    main()