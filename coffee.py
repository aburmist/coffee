import streamlit as st
from streamlit_gsheets import GSheetsConnection
import pandas as pd
import datetime

# Create a connection object
conn = st.connection("gsheets", type=GSheetsConnection)

def submit():
    df = conn.read(
        ttl=0,
        usecols=['coffee_weight', 'coffee_grind', 'water_weight', 'water_temperature', 'brew_time', 'brew_method', 'rating', 'comment', 'date']
    )
    df = df.dropna(how='all')

    # Get the current date and time
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

# Form
st.title('Coffee Taster ☕')
with st.form(key='my_form'):
    st.subheader('**Record your coffee**')
    # Input widgets
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        coffee_grind = st.number_input('Grind size', max_value=40, min_value=1, step=1)
        brew_method = st.selectbox('Select brew method', ['Espresso', 'Aeropress', 'Pour Over', 'Clever', 'French Press', 'Moka'])  
    
    with col2:
        coffee_weight = st.number_input('Coffee weight (g)', step=0.1)
        
        water_weight = st.number_input('Water weight (g)', step=10)

    with col3:
        water_temperature = st.selectbox('Temperature', ['175 Green', '185 White', '190 Oolong', '200 FrenchPress', 'Boil'])
        rating = st.selectbox('Rating', ['⭐️', '⭐️⭐️', '⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️', '⭐️⭐️⭐️⭐️⭐️'])

    with col4:
        brew_time = st.number_input('Brew time (s)', step=1)
        comment = st.text_input("Write comment")
    
    submitted = st.form_submit_button('Submit')

if submitted:
    submit()
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
else:
    st.write('☝️ Record coffee!')