

#Package Rshiny
library(shiny)
library(shinythemes)
library(shinydashboard)
library(DBI)
library(RMySQL)
library(plotly)
library(DT)
library(dplyr)
library(ggplot2)
library(lubridate)
library(rsconnect)

# Konfigurasi Database
db_config <- list(
  host = "127.0.0.1",
  port = 3306,
  user = "root",
  password = "",
  dbname = "mds_db_buku"
)

# Fungsi koneksi ke database
connect_db <- function() {
  dbConnect(
    RMySQL::MySQL(),
    host = db_config$host,
    port = db_config$port,
    user = db_config$user,
    password = db_config$password,
    dbname = db_config$dbname
  )
}

# Fungsi untuk membaca data buku dengan JOIN ke tabel lain
load_books <- function() {
  conn <- connect_db()
  
  query <- "
    SELECT 
      buku.id_buku,
      buku.judul_buku,
      penulis.nama_penulis,
      penerbit.nama_penerbit,
      kategori.nama_kategori,
      buku.ISBN,
      buku.tahun_terbit,
      buku.Reviewer,
      buku.rating,
      buku.jumlah_halaman,
      buku.link_buku,
      buku.deskripsi,
      buku.coverurl
    FROM buku
    LEFT JOIN penulis ON buku.id_penulis = penulis.id_penulis
    LEFT JOIN penerbit ON buku.id_penerbit = penerbit.id_penerbit
    LEFT JOIN kategori ON buku.id_kategori = kategori.id_kategori
  "
  
  books <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  books$rating <- as.numeric(books$rating)
  return(books)
}

# Define UI for application that draws a histogram

###########################
ui <- fluidPage(
  theme = shinytheme("cerulean"),
  
  # Navbar Ramping dengan Warna Cerulean
  tags$head(tags$style(HTML("
    .navbar-fixed {
      position: fixed;
      top: 0;
      width: 100%;
      z-index: 1000;
      background-color: #0275d8;
      color: white;
      padding: 5px 15px;
      box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1);
      height: 45px;
      display: flex;
      align-items: center;
    }
    .container-fluid { margin-top: 55px; }
    .footer { text-align: center; padding: 10px; background: #0275d8; color: white; margin-top: 20px; }
    .search-bar {
      display: flex;
      align-items: center;
      background: white;
      border-radius: 5px;
      padding: 3px;
      gap: 5px;
      max-width: 400px;
      margin: auto;
    }
    .search-bar select, .search-bar input {
      border: 1px solid #ccc;
      padding: 5px;
      border-radius: 5px;
      font-size: 12px;
      flex-grow: 1;
      width: 100px;
    }
    .search-bar button {
      background: #0275d8;
      color: white;
      border: none;
      padding: 5px 8px;
      border-radius: 5px;
      font-size: 12px;
      cursor: pointer;
    }
    .navbar-title {
      font-size: 16px;
      margin-left: 10px;
      margin-top: 10px;
    }
  "))),
  
  # Navbar Minimalis
  div(class = "navbar-fixed",
      fluidRow(
        column(3, h4("bukupedia", class = "navbar-title", style = "color: white;")),
        column(6, div(class = "search-bar",
                      selectInput("search_type", label = NULL, 
                                  choices = c("All", "Title", "Author", "Publisher", "Category"), 
                                  selected = "All"),
                      textInput("search_text", label = NULL, placeholder = "Search"),
                      actionButton("cari", icon("search"), class = "btn")
        ))
      )
  ),
  
  # Infografis
  fluidRow(
    column(6, box(title = "Kategori Buku", plotlyOutput("pie_chart"), width = 12)),
    column(6, box(title = "Tahun Terbit", plotlyOutput("bar_chart"), width = 12))
  ),
  
  # Tabel Buku
  fluidRow(
    column(12, box(title = "Daftar Buku", DTOutput("buku_table"), width = 12))
  ),
  
  # Footer
  div(class = "footer", "Copyright 2025 - Tugas Kelompok 7 Manajemen Data Statistika")
)

############################
# Define server logic required to draw a histogram
server <- function(input, output, session) {
  buku_data <- reactiveVal(load_books())
  
  # Fungsi pencarian data berdasarkan input pengguna
  observeEvent(input$cari, {
    conn <- connect_db()
    
    search_col <- switch(input$search_type,
                         "All" = NULL,
                         "Title" = "judul_buku",
                         "Author" = "nama_penulis",
                         "Publisher" = "nama_penerbit",
                         "Category" = "nama_kategori")
    
    query <- "
      SELECT 
      buku.id_buku,
      buku.judul_buku,
      penulis.nama_penulis,
      penerbit.nama_penerbit,
      kategori.nama_kategori,
      buku.ISBN,
      buku.tahun_terbit,
      buku.Reviewer,
      buku.rating,
      buku.jumlah_halaman,
      buku.link_buku,
      buku.deskripsi,
      buku.coverurl
      FROM buku
      LEFT JOIN penulis ON buku.id_penulis = penulis.id_penulis
      LEFT JOIN penerbit ON buku.id_penerbit = penerbit.id_penerbit
      LEFT JOIN kategori ON buku.id_kategori = kategori.id_kategori
    "
    
    if (!is.null(search_col) && input$search_text != "") {
      query <- sprintf("%s WHERE %s LIKE '%%%s%%'", query, search_col, input$search_text)
    }
    
    books <- dbGetQuery(conn, query)
    dbDisconnect(conn)
    buku_data(books)
  })
  
  # Pie Chart (Distribusi Kategori Buku)
  output$pie_chart <- renderPlotly({
    kategori_data <- buku_data() %>%
      count(nama_kategori) %>%
      rename(Jumlah = n)
    
    plot_ly(kategori_data, labels = ~nama_kategori, values = ~Jumlah, type = "pie",
            textinfo = "percent+label",  
            textposition = "inside",  
            insidetextfont = list(color = "#FFFFFF", size = 12),  
            outsidetextfont = list(size = 10),  
            marker = list(line = list(color = "black", width = 1))) %>%  #
      layout(
        title = "Distribusi Kategori Buku",
        showlegend = TRUE,  
        legend = list(x = 1.05, y = 0.5),  
        margin = list(l = 20, r = 150, t = 50, b = 20)  
      )
  })
  
  # Bar Chart (Jumlah Buku per Tahun)
  output$bar_chart <- renderPlotly({
    tahun_data <- buku_data() %>%
      count(tahun_terbit) %>%   # Hitung jumlah buku per tahun
      rename(Tahun = tahun_terbit, Jumlah = n)
    
    p <- ggplot(tahun_data, aes(x = reorder(Tahun, as.numeric(Tahun)), y = Jumlah, fill = Tahun)) +
      geom_bar(stat = "identity") +
      theme_minimal() +
      labs(title = "Jumlah Buku per Tahun", x = "Tahun", y = "Jumlah") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    
    ggplotly(p)
  })
  
  # Tabel Buku
  output$buku_table <- renderDT({
    buku_data() %>%
      mutate(
        judul_buku = sprintf('<a href="#" onclick="Shiny.setInputValue(\'selected_book\', \'%s\', {priority: \'event\'});">%s</a>', id_buku, judul_buku),
        link_buku = sprintf('<a href="%s" target="_blank">Get</a>', link_buku),
        # Konversi rating ke numerik dengan aman
        rating = suppressWarnings(as.numeric(trimws(rating))), 
        
        # Ganti NA atau nilai kosong dengan "N/A", dan batasi rating dalam rentang 0-5
        rating_display = ifelse(is.na(rating) | rating == "" | rating < 0 | rating > 5, 
                                "N/A", sprintf("%.1f", rating))
      ) %>%
      select(judul_buku, nama_penulis, nama_penerbit, nama_kategori, tahun_terbit, ISBN, jumlah_halaman, rating_display, link_buku) %>%
      datatable(escape = FALSE, options = list(pageLength = 5))
  })
  
  # Popup Detail Buku
  observeEvent(input$selected_book, {
    selected_data <- buku_data() %>% filter(id_buku == input$selected_book)
    
    if (nrow(selected_data) == 0) {
      showNotification("Buku tidak ditemukan.", type = "error")
      return()
    }
    
    showModal(modalDialog(
      title = selected_data$judul_buku,
      size = "l",
      fluidRow(
        column(5, align = "center",
               img(src = selected_data$coverurl, width = "100%", style = "max-width: 300px;")
        ),
        column(7, 
               h2(selected_data$judul_buku, style = "font-weight: bold;"),
               tags$hr(),
               strong("Kategori:"), p(selected_data$nama_kategori),
               strong("Penulis:"), p(selected_data$nama_penulis),
               strong("Penerbit:"), p(selected_data$nama_penerbit),
               strong("ISBN:"), p(selected_data$ISBN),
               strong("Tahun Terbit:"), p(selected_data$tahun_terbit),
               strong("Jumlah Halaman:"), p(selected_data$jumlah_halaman),
               strong("Jumlah Review:"), p(selected_data$Reviewer),
               strong("Deskripsi Buku:"), p(selected_data$deskripsi),
               strong("Link Buku:"), a("Google Play", href = selected_data$link_buku, target = "_blank")
        )
      ),
      easyClose = TRUE, footer = NULL
    ))
  })
}


# Run the application 
shinyApp(ui = ui, server = server)
